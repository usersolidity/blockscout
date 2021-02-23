defmodule Indexer.Transform.AddressCoinBalances do
  @moduledoc """
  Extracts `Explorer.Chain.Address.CoinBalance` params from other schema's params.
  """

  def params_set(%{} = import_options) do
    Enum.reduce(import_options, MapSet.new(), &reducer/2)
  end

  defp reducer({:beneficiary_params, beneficiary_params}, acc) when is_list(beneficiary_params) do
    Enum.into(beneficiary_params, acc, fn %{address_hash: address_hash, block_number: block_number}
                                          when is_binary(address_hash) and is_integer(block_number) ->
      %{address_hash: address_hash, block_number: block_number}
    end)
  end

  defp reducer({:blocks_params, blocks_params}, acc) when is_list(blocks_params) do
    # a block MUST have a miner_hash and number
    Enum.into(blocks_params, acc, fn %{miner_hash: address_hash, number: block_number}
                                     when is_binary(address_hash) and is_integer(block_number) ->
      %{address_hash: address_hash, block_number: block_number}
    end)
  end

  defp reducer({:internal_transactions_params, internal_transactions_params}, initial)
       when is_list(internal_transactions_params) do
    Enum.reduce(internal_transactions_params, initial, &internal_transactions_params_reducer/2)
  end

  defp reducer({:celo_transfers, celo_transfers}, acc) when is_list(celo_transfers) do
    Enum.reduce(celo_transfers, acc, fn %{from_address_hash: from, to_address_hash: to, block_number: bn}, lst ->
      lst
      |> MapSet.put(%{block_number: bn, address_hash: to})
      |> MapSet.put(%{block_number: bn, address_hash: from})
    end)
  end

  defp reducer({:logs_params, logs_params}, acc) when is_list(logs_params) do
    # a log MUST have address_hash and block_number
    logs_params
    |> Enum.into(acc, fn
      %{address_hash: address_hash, block_number: block_number}
      when is_binary(address_hash) and is_integer(block_number) ->
        %{address_hash: address_hash, block_number: block_number}

      %{type: "pending"} ->
        nil
    end)
    |> Enum.reject(fn val -> is_nil(val) end)
    |> MapSet.new()
  end

  defp reducer({:transactions_params, transactions_params}, initial) when is_list(transactions_params) do
    Enum.reduce(transactions_params, initial, &transactions_params_reducer/2)
  end

  defp reducer({:block_second_degree_relations_params, block_second_degree_relations_params}, initial)
       when is_list(block_second_degree_relations_params),
       do: initial

  defp internal_transactions_params_reducer(%{block_number: block_number} = internal_transaction_params, acc)
       when is_integer(block_number) do
    case internal_transaction_params do
      %{type: "call"} ->
        acc

      %{type: "create", error: _} ->
        acc

      %{type: "create", created_contract_address_hash: address_hash} when is_binary(address_hash) ->
        MapSet.put(acc, %{address_hash: address_hash, block_number: block_number})

      %{type: "selfdestruct", from_address_hash: from_address_hash, to_address_hash: to_address_hash}
      when is_binary(from_address_hash) and is_binary(to_address_hash) ->
        acc
        |> MapSet.put(%{address_hash: from_address_hash, block_number: block_number})
        |> MapSet.put(%{address_hash: to_address_hash, block_number: block_number})
    end
  end

  defp transactions_params_reducer(
         %{block_number: block_number, from_address_hash: from_address_hash} = transaction_params,
         initial
       )
       when is_integer(block_number) and is_binary(from_address_hash) do
    # a transaction MUST have a `from_address_hash`
    acc1 = MapSet.put(initial, %{address_hash: from_address_hash, block_number: block_number})

    # `to_address_hash` is optional
    acc =
      case transaction_params do
        %{to_address_hash: to_address_hash} when is_binary(to_address_hash) ->
          MapSet.put(acc1, %{address_hash: to_address_hash, block_number: block_number})

        _ ->
          acc1
      end

    # also gas fee recipient
    acc2 =
      case transaction_params do
        %{gas_fee_recipient_hash: hash, gas_currency_hash: nil}
        when is_binary(hash) and hash != "0x0000000000000000000000000000000000000000" ->
          MapSet.put(acc, %{address_hash: hash, block_number: block_number})

        _ ->
          acc
      end

    acc2
  end
end
