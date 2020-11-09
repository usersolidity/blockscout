# Walletapi

## Setting up WalletApi
To run walletapi:

  * Install dependencies with `mix do deps.get, deps.compile, compile`
  * Set walletapi port `export WALLETAPI_PORT=4002`
  * Set currency layer api key `export CURRENCY_LAYER_ACCESS_KEY=[ACCESS KEY]`
  * Running `mix phx.server` on main projects will run the walletapi

Now you can visit [`localhost:4002/[endpoint]`](http://localhost:4002) from your browser.

## EndPoints

There are two endpoints provided by the walletapi

1. [`/graphiql`](http://localhost:4002/graphiql) -> allows to test the graphql queries using graphql interface

2. [`/walletapi`](http://localhost:4002/walletapi) -> api endpoint for the Wallet

## Testing

To Test the project:

  * Change the environment `export MIX_ENV=test`
  * Go to walletapi folder `cd apps/walletapi/`
  * Run `mix test`
