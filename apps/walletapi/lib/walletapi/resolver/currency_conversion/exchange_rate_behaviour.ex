defmodule WalletAPI.Resolver.CurrencyConversion.ExchangeRateBehaviour do
  @callback query_exchange_rate(String.t(),String.t(), integer()) :: any
end
