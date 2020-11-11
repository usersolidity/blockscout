defmodule WalletAPI.Resolver.TransactionResolver.RawTransaction do
  @moduledoc """
    Return the transaction data for the address provided
  """
  alias Explorer.Chain.Wei
  def get_transaction, do: Application.get_env(:walletapi, :get_transaction)
  #   alias WalletAPI.Resolver.TransactionResolver.GetTransaction

  def get_raw_token_transactions(args) do
    address = String.downcase(to_string(args.address))

    # depending upon the MIX_ENV value it will call the WalletAPI.getTransaction module or
    # GetTransactionBehaviorMock module in the test file
    nodes = get_transaction().get_transaction_data(args)

    transfer =
      Enum.map(nodes, fn node ->
        Map.put(node, :celo_transfer, get_relevant_transfer(node, address))
      end)

    {:ok, transfer}
  end

  defp get_relevant_transfer(transfer_tx, address) do
    %{fee_token: fee_token, celo_transfer: celo_transfer} = transfer_tx

    transfers =
      if(fee_token && fee_token != "cGLD") do
        # When fees are NOT paid in the utility token (cGLD)
        # the transfers contain fee transfers
        get_transfers_unrelated_to_fees(transfer_tx)
      else
        celo_transfer
      end

    # Filter out transfers unrelated to the queried address
    Enum.filter(transfers, fn %{from_address_hash: from_address, to_address_hash: to_address} ->
      String.downcase(from_address) == address || String.downcase(to_address) == address
    end)
  end

  defp get_total_fees(transfer_tx, start, transfer_count) do
    transfer_tx[:celo_transfer]
    |> Enum.slice(start, transfer_count)
    |> Enum.reduce(0, fn fee_tx, acc ->
      Decimal.add(acc, fee_tx[:value])
    end)
  end

  defp get_expected_total_fees(transfer_tx) do
    gas_fee = transfer_tx[:gas_price] |> Wei.to(:wei) |> Decimal.mult(transfer_tx[:gas_used])
    gateway_fee = transfer_tx[:gateway_fee] || 0
    Decimal.add(gas_fee, gateway_fee |> Wei.to(:wei))
  end

  defp get_valid_transfers(transfer_tx, transfer_count, expected_fee_transfers_count) do
    start = transfer_count - expected_fee_transfers_count
    # filter out fee transfers
    transfer = Enum.slice(transfer_tx[:celo_transfer], 0, start)
    total_fees = get_total_fees(transfer_tx, start, transfer_count)
    expected_total_fee = get_expected_total_fees(transfer_tx)
    # Make sure our assertion is correct
    case total_fees == expected_total_fee do
      true ->
        transfer

      # If false, something is wrong with our assertion
      false ->
        {:error, "Fee transfers don't add up for tx " <> transfer_tx[:transaction_hash]}
    end
  end

  # Find transfers which are unrelated to the fees.
  # We take advantage of the following property:
  # the fees are always the last transfers
  # This is only valid for transactions paying for fees in a token
  # different from the utility token (cGLD)
  defp get_transfers_unrelated_to_fees(transfer_tx) do
    transfer_count = Enum.count(transfer_tx[:celo_transfer])
    # 3 fee transfers when gatewayFeeRecipient is set, otherwise 2
    expected_fee_transfers_count =
      if(transfer_tx[:gateway_fee_recipient]) do
        3
      else
        2
      end

    case transfer_count < expected_fee_transfers_count do
      false -> get_valid_transfers(transfer_tx, transfer_count, expected_fee_transfers_count)
      true -> {:error, ["Cannot determine fee transfers for tx " <> transfer_tx[:transaction_hash]]}
    end
  end
end
