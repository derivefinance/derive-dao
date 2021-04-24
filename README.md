# derive-dao
Smart contracts belonging to the (upcoming) Derive Finance DAO.

At the time of writing, this repository contains the DRV token contract code and its dependencies.

The DRV token is **live** on BSC mainnet, see it on [bscscan.com.](https://bscscan.com/token/0x4aC8B09860519d5A17B6ad8c86603aa2f07860d6)  

## Instructions
To install dependencies: ```npm install```

### Building contracts
```npm run build```

### Deploying contracts

Create an environment variable with the private key of your choice, e.g.:

```export PRIVATE_KEY_TESTNET=0x0000000000000000000000000000000000000000000000000000000000000000``` 

To deploy on BSC testnet: ```npm run deploy-testnet```

See package.json and truffle-config.js for more environments.