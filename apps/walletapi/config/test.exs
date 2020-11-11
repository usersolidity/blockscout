use Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# config :walletapi, Explorer.Repo,
#   pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :walletapi, WalletApi.Endpoint,
  http: [port: System.get_env("WALLETAPI_PORT")],
  server: false

config :walletapi,
  firebase_database_url: "https://celo-mobile-alfajores.firebaseio.com/",
  verification_rewards_address: "0xb4fdaf5f3cd313654aa357299ada901b1d2dd3b5",
  get_transaction: GetTransactionBehaviorMock,
  gold_exchange_rate_behaviour: ExchangeRateMock,
  exchange_rate_behaviour: ExchangeRateMock

config :ethereumex,
  url: "https://alfajores-forno.celo-testnet.org"

# Print only warnings and errors during test
config :logger, level: :warn
