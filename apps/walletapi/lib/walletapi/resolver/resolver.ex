defmodule WalletApi.Resolver do
    alias ABI
    alias DateTime
    alias WalletAPI.Resolver.TransactionResolver.{RawTransaction, TokenTransaction, ExchangeTransaction}

    def get_token_transactions(_, args, _) do
        {:ok, raw_transfer_txs} = RawTransaction.get_raw_token_transactions(args)

        user_address = String.downcase(to_string(args.address))
        token = args.token
        #Generate Final Events
        events = Enum.reduce(raw_transfer_txs,[], fn(transfer_tx, acc) ->
            %{celo_transfer: transfers} = transfer_tx
            case Enum.count(transfers) do
                0 -> acc #Normal Contract Call
                1 -> #Regular Token Transfer
                    value = TokenTransaction.get_regular_token_transaction(user_address, transfer_tx, Enum.at(transfers,0))
                    [value| acc]
                2 -> #Exchange Event with two corresponding transfer (in and out)
                    value = ExchangeTransaction.get_exchange_transaction(user_address, token, transfer_tx, transfers)
                    [value| acc]
                _ -> IO.puts("Unhandled transfers for tx #{transfer_tx[:transaction_hash]}")
                    acc
            end
        end)
        events = events |> Enum.filter(fn(event) -> event[:amount][:currency_code] == token end) |> Enum.sort_by(&Map.fetch(&1, :timestamp),&>=/2)

        nodes = Enum.map(events, fn(event) ->
            %{:node => event, :cursor => "TODO"}
        end)
        page_info = %{:has_previous_page => false, :has_next_page => false, :start_cursor => "TODO", :end_cursor => "TODO"}
        result = %{:edges => nodes, :page_info => page_info}
        {:ok, result}
    end
end
