defmodule WalletAPI.Resolver.CurrencyConversion.ExchangeRateBehaviour do
  @moduledoc """
    Behavior required for mocking data for testing
    Acts like an interface and requires query_exchange_rate() function to be implemented
    by all modules importing this behavior
  """
  @callback query_exchange_rate(String.t(), String.t(), integer()) :: any
end
