defmodule WalletAPI.Resolver.TransactionResolver.ExchangeTransaction do
  @moduledoc """
    convert transaction into ExchangeTransaction type
  """
  defp get_implied_exchange_rate(in_transfer, out_transfer) do
    cond do
      in_transfer[:token] == "cGLD" && out_transfer[:token] == "cUSD" ->
        %{"cGLD/cUSD" => Decimal.div(out_transfer[:value], in_transfer[:value])}

      out_transfer[:token] == "cGLD" && in_transfer[:token] == "cUSD" ->
        %{"cGLD/cUSD" => Decimal.div(in_transfer[:value], out_transfer[:value])}

      true ->
        {:error}
    end
  end

  def get_exchange_transaction(user_address, token, transfer_tx, transfers) do
    wei = Decimal.new(1_000_000_000_000_000_000)
    %{transaction_hash: hash, block_number: block, timestamp: timestamp} = transfer_tx

    first_transfer = Enum.at(transfers, 0)
    second_transfer = Enum.at(transfers, 1)

    in_transfer =
      if String.downcase(first_transfer[:from_address_hash]) == user_address do
        first_transfer
      else
        second_transfer
      end

    out_transfer =
      if String.downcase(first_transfer[:from_address_hash]) == user_address do
        second_transfer
      else
        first_transfer
      end

    # Find the transfer related to the queried token
    [token_transfer] =
      Enum.filter([in_transfer, out_transfer], fn event ->
        event[:token] === token
      end)

    if(token_transfer == []) do
      "undefined"
    else
      implied_exchange_rate = get_implied_exchange_rate(in_transfer, out_transfer)

      value =
        Decimal.div(
          Decimal.mult(
            token_transfer[:value],
            if token_transfer === in_transfer do
              -1
            else
              1
            end
          ),
          wei
        )

      %{
        :type => :exchange,
        :timestamp => DateTime.to_unix(timestamp, :millisecond),
        :block => block,
        :hash => hash,
        :amount => %{
          # Signed amount relative to the account currency
          :value => value,
          :currency_code => token_transfer[:token],
          :timestamp => DateTime.to_unix(timestamp, :millisecond),
          :implied_exchange_rates => implied_exchange_rate
        },
        :maker_amount => %{
          :value => Decimal.div(in_transfer[:value], wei),
          :currency_code => in_transfer[:token],
          :timestamp => DateTime.to_unix(timestamp, :millisecond),
          :implied_exchange_rates => implied_exchange_rate
        },
        :taker_amount => %{
          :value => Decimal.div(out_transfer[:value], wei),
          :currency_code => out_transfer[:token],
          :timestamp => DateTime.to_unix(timestamp, :millisecond),
          :implied_exchange_rates => implied_exchange_rate
        }
      }
    end
  end
end
