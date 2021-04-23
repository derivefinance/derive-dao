# derive-dao
Smart contracts belonging to the (upcoming) Derive Finance DAO.

At the time of writing, this repository contains the DRV token contract code and its dependencies.

## Installing dependencies
```npm install```

## Building contracts
```npm run build```

## Deploying contracts

Create an environment variable with your desider private key, e.g.:

```export PRIVATE_KEY_TESTNET=0x0000000000000000000000000000000000000000000000000000000000000000``` 

or 

```export PRIVATE_KEY_MAINNET=0x0000000000000000000000000000000000000000000000000000000000000000```

To deploy on BSC testnet ```npm run deploy-testnet```

To deploy on BSC testnet ```npm run deploy-mainnet```
