# Walletapi

## Setting up WalletApi
To run walletapi using mix:

  * Install dependencies with `mix do deps.get, deps.compile, compile`
  * Set walletapi port `export WALLETAPI_PORT=4002`
  * Set currency layer api key `export CURRENCY_LAYER_ACCESS_KEY=[ACCESS KEY]`
  * Running `mix phx.server` on main projects will run the walletapi

Now you can visit [`localhost:4002/[endpoint]`](http://localhost:4002) from your browser.

## Running using DOCKER
To run walletapi using docker:
  * Run following command from main project
  `cd docker`
  `export NETWORK=Celo`
  `export SUBNETWORK="Celo Integration"`
  `export ETHEREUM_JSONRPC_VARIANT=geth`
  `export ETHEREUM_JSONRPC_HTTP_URL=http://104.198.100.15:8545`
  `export ETHEREUM_JSONRPC_TRACE_URL=http://104.198.100.15:8545`
  `export ETHEREUM_JSONRPC_WS_URL=ws://104.198.100.15:8546`
  `export WALLETAPI_PORT=4002`
  `export CURRENCY_LAYER_ACCESS_KEY=[ACCESS_KEY]`
  `make start`
  

To Test the project:

  * Change the environment `export MIX_ENV=test`
  * Go to walletapi folder `cd apps/walletapi/`
  * Run `mix test`

## EndPoints

There are two endpoints provided by the walletapi

1. [`/graphiql`](http://localhost:4002/graphiql) -> allows to test the graphql queries using graphql interface

2. [`/walletapi`](http://localhost:4002/walletapi) -> api endpoint for the Wallet

## Testing

To Test the project:

  * Change the environment `export MIX_ENV=test`
  * Go to walletapi folder `cd apps/walletapi/`
  * Run `mix test`
