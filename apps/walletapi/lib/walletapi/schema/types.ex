defmodule WalletApi.Schema.Types do
  @moduledoc """
    GraphQL Types
  """
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  @token_transfer_types [
    :received,
    :escrow_received,
    :escrow_sent,
    :sent,
    :faucet,
    :verification_fee,
    :verification_reward
  ]
  import_types(Absinthe.Type.Custom)
  import_types(WalletApi.Schema.Scalars)

  alias WalletApi.CurrencyConversion.CurrencyConversionAPI

  @desc """
  BlockScout Transcation Record
  """

  @desc "Event Types"
  enum :event_types do
    value(:exchange)
    value(:received)
    value(:sent)
    value(:faucet)
    value(:verification_reward)
    value(:verification_fee)
    value(:escrow_sent)
    value(:escrow_received)
  end

  @desc "Tokens"
  enum :token do
    value(:c_usd, name: "cUSD", as: "cUSD")
    value(:c_gld, name: "cGLD", as: "cGLD")
  end

  @desc "Sort"
  enum :sort do
    value(:asc, name: "asc", as: "asc")
    value(:desc, name: "desc", as: "desc")
  end

  # Query params as defined by Blockscout's API
  interface(:event_args) do
    field(:address, :string)
    field(:sort, :sort)
    field(:startblock, :integer)
    field(:endblock, :integer)
    field(:page, :integer)
    field(:offset, :integer)
  end

  interface(:token_transaction_args) do
    field(:address, :string)
    field(:token, :token)
    field(:local_currency_code, :string)
  end

  object(:exchange_rate) do
    field(:rate, :decimal)
  end

  input_object(:currency_conversion_args) do
    field(:source_currency_code, :string)
    field(:currency_code, :string)
    field(:timestamp, :integer)
    field(:implied_exchange_rates, :map)
  end

  input_object(:map) do
    field(:key, :string)
    field(:value, :decimal)
  end

  input_object(:money_amount) do
    field(:value, :decimal)
    field(:currency_code, :string)
    field(:implied_exchange_rates, :map)
    field(:timestamp, :integer)
  end

  object :money_amounts do
    field(:value, non_null(:decimal))
    field(:currency_code, non_null(:string))

    field(:local_amount, :local_money_amount) do
      arg(:money_amount, :money_amount)
      resolve(&resolve_local_amount/3)
    end
  end

  object :local_money_amount do
    field(:value, non_null(:decimal))
    field(:currency_code, non_null(:string))
    field(:exchange_rate, non_null(:decimal))
  end

  @desc "Token Transaction Types"
  enum :token_transaction_type do
    value(:exchange)
    value(:received)
    value(:sent)
    value(:faucet)
    value(:verification_reward)
    value(:verification_fee)
    value(:escrow_sent)
    value(:escrow_received)
    value(:invite_sent)
    value(:invite_received)
    value(:pay_request)
    value(:network_fee)
  end

  interface(:token_transaction) do
    field(:type, non_null(:token_transaction_type))
    field(:timestamp, non_null(:integer))
    field(:block, non_null(:string))
    field(:amount, non_null(:money_amounts))
    field(:hash, non_null(:string))

    resolve_type(&resolve_transaction_type/2)
  end

  object(:token_transfer) do
    field(:type, non_null(:token_transaction_type))
    field(:timestamp, non_null(:integer))
    field(:block, non_null(:string))
    field(:amount, non_null(:money_amounts))
    field(:hash, non_null(:string))
    field(:address, non_null(:address))
    field(:comment, :string)
    field(:token, non_null(:token))

    interface(:token_transaction)
  end

  object(:token_exchange) do
    field(:type, non_null(:token_transaction_type))
    field(:timestamp, non_null(:integer))
    field(:block, non_null(:string))
    field(:amount, non_null(:money_amounts))
    field(:hash, non_null(:string))
    field(:taker_amount, non_null(:money_amounts))
    field(:maker_amount, non_null(:money_amounts))

    interface(:token_transaction)
  end

  object(:token_transaction_connection) do
    field(:edges, non_null(list_of(non_null(:token_transaction_edge))))
    field(:page_info, non_null(:page_info))
  end

  object(:token_transaction_edge) do
    field(:node, :token_transaction)
    field(:cursor, non_null(:string))
  end

  defp resolve_transaction_type(obj, _) do
    if(obj.type == :exchange) do
      :token_exchange
    else
      if Enum.member?(@token_transfer_types, obj.type) do
        :token_transfer
      end
    end
  end

  defp resolve_local_amount(money_amount, _, %{context: %{local_currency_code: local_currency_code}}) do
    args = %{
      :source_currency_code => money_amount[:currency_code],
      :currency_code => local_currency_code,
      :timestamp => money_amount[:timestamp],
      :implied_exchange_rates => money_amount[:implied_exchange_rates]
    }

    {:ok, %{rate: rate}} = CurrencyConversionAPI.get_exchange_rate(%{}, args, %{})

    local_amount = %{
      :value => Decimal.mult(money_amount[:value], rate),
      :currency_code => local_currency_code,
      :exchange_rate => rate
    }

    {:ok, local_amount}
  end
end
