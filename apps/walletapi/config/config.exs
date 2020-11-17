# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :walletapi,
  exchange_rates_api: "https://apilayer.net/api",
  faucet_address: "0x456f41406B32c45D59E539e4BBA3D7898c3584dA",
  registry_contract_address: "0x000000000000000000000000000000000000ce10",
  ecto_repos: [Explorer.Repo]

# Configures the endpoint
config :walletapi, WalletApi.Endpoint,
  url: [
    scheme: System.get_env("BLOCKSCOUT_PROTOCOL") || "http",
    host: System.get_env("BLOCKSCOUT_HOST") || "localhost",
    path: System.get_env("NETWORK_PATH") || "/"
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  render_errors: [view: WalletApi.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Walletapi.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
# config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
