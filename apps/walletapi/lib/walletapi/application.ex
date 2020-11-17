defmodule Walletapi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias WalletApi.Endpoint

  def start(_type, _args) do
    children = [
      # Start the Endpoint (http/https)
      WalletApi.Endpoint,
      # Start the cache service to store exchange rate:
      # ttl: check after every day
      # global_ttl: store it for 1 year
      con_cache_child_spec(:exchange_rate_cache, 24 * 60 * 60, 365 * 24 * 60 * 60, true),
      # Start the cache service to store contract_address
      # ttl: check after every hour
      # global_ttl: store it for 1 day
      con_cache_child_spec(:contract_address_cache, 60 * 60, 24 * 60 * 60, false)
    ]

    opts = [strategy: :one_for_one, name: WalletApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp con_cache_child_spec(name, ttl, global_ttl, reset_global_ttl) do
    Supervisor.child_spec(
      {
        ConCache,
        [
          name: name,
          ttl_check_interval: ttl,
          global_ttl: global_ttl,
          touch_on_read: reset_global_ttl
        ]
      },
      id: {ConCache, name}
    )
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
