defmodule WalletAPI.Resolver.TransactionResolver.GetTransactionBehavior do
  @callback get_transaction_data(args :: map()) :: list()
end

defmodule WalletAPI.Resolver.TransactionResolver.GetTransaction do
  alias Explorer.{GraphQL, Repo}
  alias Absinthe.Relay.Connection
  @behaviour WalletAPI.Resolver.TransactionResolver.GetTransactionBehavior

  defp options(%{before: _}), do: []

  defp options(%{count: count}), do: [count: count]

  defp options(_), do: []

  defp get_trasactions_history(%{address: address} = args) do
    args = Map.put(args, :first, 100)
    connection_args = Map.take(args, [:after, :before, :first, :last])

    address
    |> GraphQL.txtransfers_query_for_address()
    |> Connection.from_query(&Repo.all/1, connection_args, options(args))
  end

  defp get_celo_tx_transfer(args, node) do
    args = Map.put(args, :first, 10)

    node[:node][:transaction_hash]
    |> GraphQL.celo_tx_transfers_query_by_txhash()
    |> Connection.from_query(&Repo.all/1, args)
  end

  def get_transaction_data(args) do
    {:ok, transfer_transactions} = get_trasactions_history(args)

    transactions =
      Enum.map(transfer_transactions[:edges], fn node ->
        {:ok, data} = get_celo_tx_transfer(args, node)

        celo_transfer =
          Enum.map(data[:edges], fn trasaction ->
            %{
              :from_address_hash => to_string(trasaction[:node][:from_address_hash]),
              :to_address_hash => to_string(trasaction[:node][:to_address_hash]),
              :value => trasaction[:node][:value],
              :token => trasaction[:node][:token]
            }
          end)

        Map.put(node[:node], :celo_transfer, celo_transfer)
      end)

    transactions
  end
end
