defmodule WalletApi.Schema do
    @moduledoc false
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern
    alias WalletApi.Resolver
    alias WalletApi.CurrencyConversion.CurrencyConversionAPI
    import_types(WalletApi.Schema.Types)

    query do
        @desc "Get Transaction Data"
        field :token_transactions, :token_transaction_connection do
            arg(:address, non_null(:address))
            arg(:token, non_null(:token))
            arg(:local_currency_code, :string, default_value: "USD")

            resolve(&Resolver.get_token_transactions/3)
        end

        @desc "Get Exchange Rates"
        field :currency_conversion, :exchange_rate do
            arg(:source_currency_code, :string)
            arg(:currency_code, non_null(:string))
            arg(:timestamp, :integer)
            resolve(&CurrencyConversionAPI.get_exchange_rate/3)
        end
    end
end
