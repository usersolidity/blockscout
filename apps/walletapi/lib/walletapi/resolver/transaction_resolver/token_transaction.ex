defmodule WalletAPI.Resolver.TransactionResolver.TokenTransaction do

  alias WalletApi.Utils
  @faucet_address Application.fetch_env!(:walletapi, :faucet_address)
  @verification_rewards_address Application.fetch_env!(:walletapi, :verification_rewards_address)

  defp get_comment(%{input: _} = transfer_tx), do: Utils.format_comment_string(to_string(transfer_tx[:input]))
  defp get_comment(_transfer_tx), do: ""

  def get_regular_token_transaction(user_address, transfer_tx, transfer) do
    wei = Decimal.new(1_000_000_000_000_000_000)
    %{transaction_hash: hash, block_number: block, timestamp: timestamp} = transfer_tx
    %{to_address_hash: event_to_address, from_address_hash: event_from_address} = transfer

    comment = get_comment(transfer_tx)
    [type, address] = resolve_transfer_event_type(
        user_address,
        event_to_address,
        event_from_address
    )

    value =  Decimal.div(Decimal.mult(transfer[:value], if (is_equal(event_from_address, user_address)) do -1 else 1 end) , wei)

    %{
        :type => type,
        :timestamp => DateTime.to_unix(timestamp, :millisecond),
        :block => block,
        :address => address,
        :comment => comment,
        :hash => hash,
        :amount => %{
            #Signed amount relative to the account currency
            :value => value,
            :currency_code => transfer[:token],
            :timestamp => DateTime.to_unix(timestamp, :millisecond)
        }
    }
  end

  defp resolve_transfer_event_type(user_address,event_to_address,event_from_address) do
    attestation_address = Utils.get_contract_address("Attestations")
    escrow_address = Utils.get_contract_address("Escrow")
    cond do
        is_equal(event_to_address,user_address) && is_equal(event_from_address, @faucet_address) ->
            [:faucet,  @faucet_address]
        is_equal(event_to_address,attestation_address) && is_equal(event_from_address, user_address) ->
            [:verification_fee, attestation_address]
        is_equal(event_to_address,user_address) && is_equal(event_from_address, @verification_rewards_address) ->
            [:verification_reward,  @verification_rewards_address]
        is_equal(event_to_address,user_address) && is_equal(event_from_address, escrow_address) ->
            [:escrow_received, event_from_address]
        is_equal(event_to_address,user_address) ->
            [:received, event_from_address]
        is_equal(event_from_address, user_address) && is_equal(event_to_address,escrow_address) ->
            [:escrow_sent, event_to_address]
        is_equal(event_from_address, user_address) ->
            [:sent, event_to_address]
        true -> IO.puts("No valid event type found")
    end
  end

  defp is_equal(address1, address2) do
    String.downcase(address1) == String.downcase(address2)
  end
end
