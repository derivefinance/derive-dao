
pragma solidity >=0.6.0 <0.8.0;

import "./libraries/ERC20.sol";
import "./interfaces/IRewardEscrow.sol";

contract ERC20DRV is ERC20(){

    event UpdateMiningParameters(uint256 time, uint256 rate, uint256 supply);
    event SetMinter(address minter);
    event SetAdmin(address admin);
    event SetRewardEscrow(address _rewardEscrow);

    address public minter;
    address public admin;

    //General constants
    uint constant YEAR = 86400 * 365;

    // Allocation:
    // =========
    // * shareholders - 30%
    // * emplyees - 3%
    // * DAO-controlled reserve - 5%
    // * Early users - 5%
    // == 43% ==
    // left for inflation: 57%

    // Supply parameters
    uint256 constant INITIAL_SUPPLY = 1_303_030_303;
    // leading to 43% premine
    uint256 constant INITIAL_RATE = 274_815_283 * 10 ** 18 / YEAR; 
    uint256 constant RATE_REDUCTION_TIME = YEAR;
    // 2 ** (1/4) * 1e18
    uint256 constant RATE_REDUCTION_COEFFICIENT = 1189207115002721024;  
    uint256 constant RATE_DENOMINATOR = 10 ** 18;
    uint256 constant INFLATION_DELAY = 86400;

    // Supply variables
    int128 public mining_epoch;
    uint256 public start_epoch_time;
    uint256 public rate;

    uint256 start_epoch_supply;
    address public RewardEscrow = address(0);

    constructor() public { 
        _name     = "Derive DAO Token";
        _symbol   = "DRV";
        _decimals = 18;        

        uint256 init_supply = INITIAL_SUPPLY * 10 ** 18;
        _balances[msg.sender] = init_supply;
        _totalSupply = init_supply;
        admin = msg.sender;
        emit Transfer(address(0), msg.sender, init_supply);

        start_epoch_time = block.timestamp + INFLATION_DELAY - RATE_REDUCTION_TIME;
        mining_epoch = -1;
        rate = 0;
        start_epoch_supply = init_supply;
    }


    function _update_mining_parameters() internal {
        /**
        *@dev Update mining rate and supply at the start of the epoch
        *     Any modifying mining call must also call this
        */
        uint256 _rate = rate;
        uint256 _start_epoch_supply = start_epoch_supply;

        start_epoch_time += RATE_REDUCTION_TIME;
        mining_epoch += 1;

        if (_rate == 0){
            _rate = INITIAL_RATE;
        } else {
            _start_epoch_supply += _rate * RATE_REDUCTION_TIME;
            start_epoch_supply = _start_epoch_supply;
            _rate = _rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;
        }
        rate = _rate;
        emit UpdateMiningParameters(block.timestamp, _rate, _start_epoch_supply);
    }

    function update_mining_parameters() external {
        /**
        * @notice Update mining rate and supply at the start of the epoch
        * @dev Callable by any address, but only once per epoch
        *     Total supply becomes slightly larger if this function is called late
        */
        require(block.timestamp >= start_epoch_time + RATE_REDUCTION_TIME, "Too soon!"); 
        _update_mining_parameters();
    }

    function start_epoch_time_write() external returns (uint256){
        /**
        *@notice Get timestamp of the current mining epoch start
        *        while simultaneously updating mining parameters
        *@return Timestamp of the epoch
        */
        uint256 _start_epoch_time = start_epoch_time;
        if (block.timestamp >= _start_epoch_time + RATE_REDUCTION_TIME){
            _update_mining_parameters();
            return start_epoch_time;
        } else {
            return _start_epoch_time;
        }
    }


    function future_epoch_time_write() external returns (uint256){
        /**
        *@notice Get timestamp of the next mining epoch start
        *        while simultaneously updating mining parameters
        *@return Timestamp of the next epoch
        */

        uint256 _start_epoch_time = start_epoch_time;
        if (block.timestamp >= _start_epoch_time + RATE_REDUCTION_TIME){
            _update_mining_parameters();
            return start_epoch_time + RATE_REDUCTION_TIME;
        } else {
            return _start_epoch_time + RATE_REDUCTION_TIME;
        }
    }

    function _available_supply() internal view returns (uint256){
        return start_epoch_supply + (block.timestamp - start_epoch_time) * rate;
    }

    function available_supply() external view returns (uint256){

        /**
        *@notice Current number of tokens in existence (claimed or unclaimed)
        */
        return _available_supply();
    }

    function rewardEscrow() internal view returns (IRewardEscrow) {
        return IRewardEscrow(RewardEscrow);
    }

    function mintable_in_timeframe(uint256 start, uint256 end)external view returns (uint256){
        /**
        *@notice How much supply is mintable from start timestamp till end timestamp
        *@param start Start of the time interval (timestamp)
        *@param end End of the time interval (timestamp)
        *@return Tokens mintable from `start` till `end`
        */
        require(start <= end, "Start must be <= end");  
        uint256 to_mint = 0;
        uint256 current_epoch_time = start_epoch_time;
        uint256 current_rate = rate;

        // Special case if end is in future (not yet minted) epoch
        if (end > current_epoch_time + RATE_REDUCTION_TIME){
            current_epoch_time += RATE_REDUCTION_TIME;
            current_rate = current_rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;
        }

        require(end <= current_epoch_time + RATE_REDUCTION_TIME, "Too far in future");  

        for(uint i = 0; i < 999; i++){  
            if(end >= current_epoch_time){
                uint256 current_end = end;
                if(current_end > current_epoch_time + RATE_REDUCTION_TIME){
                    current_end = current_epoch_time + RATE_REDUCTION_TIME;
                }
                uint256 current_start = start;
                if (current_start >= current_epoch_time + RATE_REDUCTION_TIME){
                    // We should never get here but what if...
                    break;  
                }else if(current_start < current_epoch_time){
                    current_start = current_epoch_time;
                }
                to_mint += current_rate * (current_end - current_start);

                if (start >= current_epoch_time){
                    break;
                }
            }
            current_epoch_time -= RATE_REDUCTION_TIME;
            // double-division with rounding made rate a bit less => good
            current_rate = current_rate * RATE_REDUCTION_COEFFICIENT / RATE_DENOMINATOR;  
            // This should never happen
            require(current_rate <= INITIAL_RATE, "Current rate > INITIAL_RATE");  
        }

        return to_mint;
    }

    function set_minter(address _minter) external {
        /**
        *@notice Set the minter address
        *@param _minter Address of the minter
        */
        require(msg.sender == admin, "Only admin allowed");
        minter = _minter;
        emit SetMinter(_minter);
    }

    function set_admin(address _admin) external {
        /**
        *@notice Set the new admin.
        *@dev After all is set up, admin only can change the token name
        *@param _admin New admin address
        */
        require(msg.sender == admin, "Only admin allowed");
        admin = _admin;
        emit SetAdmin(_admin);
    }

    function set_rewardEscrow(address _rewardEscrow) external {
        /**
        *@notice Set the reward escrow address
        *@param _minter Address of the minter
        */
        require(msg.sender == admin, "Only admin allowed"); 
        RewardEscrow = _rewardEscrow;
        emit SetRewardEscrow(_rewardEscrow);
    }

    function mint(address _to, uint256 _value, bool isVested) external returns (bool){
        /**
        *@notice Mint `_value` tokens and assign them to `_to`
        *@dev Emits a Transfer event originating from 0x00
        *@param _to The account that will receive the created tokens
        *@param _value The amount that will be created
        *@param isVested Will the amount be vested or not
        *@return bool success
        */
        require(msg.sender == minter || msg.sender == admin, "Only authorities allowed");  
        require(_to != address(0), "Cannot mint to 0 address");  

        if (block.timestamp >= start_epoch_time + RATE_REDUCTION_TIME){
            _update_mining_parameters();
        }
        uint256 _total_supply = _totalSupply + _value;
        require(_total_supply <= _available_supply(), "Exceeds the mintable amount");  
        _totalSupply = _total_supply;

        if (isVested) {
            require(RewardEscrow != address(0), "Reward contract not set");
            _balances[RewardEscrow] += _value; 
            rewardEscrow().appendVestingEntry(_to, _value);
            emit Transfer(address(0), RewardEscrow, _value);
        } else {
            _balances[_to] += _value;
             emit Transfer(address(0), _to, _value);
        }

        return true;
    }

    function burn(address _account, uint256 _value) external returns (bool){
        /**
        *@notice Burn `_value` tokens belonging to `msg.sender`
        *@dev Emits a Transfer event with a destination of 0x00
        *@param _account The account to burn amount from
        *@param _value The amount that will be burned
        *@return bool success
        */
        require(msg.sender == minter || msg.sender == admin, "Only authorities allowed");  

        _balances[_account] -= _value;
        _totalSupply -= _value;

        emit Transfer(_account, address(0), _value);
        return true;
    }

    function set_info(string calldata name, string calldata symbol) external {
        /**
        *@notice Set the new token info (name and symbol).
        *@param name New token name
        *@param symbol New token symbol
        */
        require(msg.sender == admin, "Only admin allowed");  
        _name = name;
        _symbol = symbol;
    }    

}