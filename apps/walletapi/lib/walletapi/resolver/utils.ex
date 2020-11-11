defmodule WalletApi.Utils do
  @registry_address Application.fetch_env!(:walletapi, :registry_contract_address)
  def format_comment_string(function_call_hex) do
    # '0xe1d6aceb' is the function selector for the transfer with comment function
    if(String.length(function_call_hex) < 10 || String.slice(function_call_hex, 0, 10) !== "0xe1d6aceb") do
      ""
    else
      try do
        data = String.slice(function_call_hex, 10..-1)

        [_, _, comment] =
          data
          |> Base.decode16!(case: :lower)
          |> ABI.TypeDecoder.decode(%ABI.FunctionSelector{
            types: [
              :address,
              {:uint, 256},
              :string
            ]
          })

        comment
      catch
        _kind, error ->
          IO.puts("Error decoding comment #{function_call_hex}: #{error}")
          ""
      end
    end
  end

  def get_contract_address(contract) do
    address_from_cache = ConCache.get(:contract_address_cache, contract)

    cond do
      address_from_cache == nil ->
        get_address_from_registry(contract)

      true ->
        address_from_cache
    end
  end

  defp get_address_from_registry(contract) do
    abi_encoded_data = ABI.encode("getAddressForString(string)", [contract]) |> Base.encode16(case: :lower)

    {:ok, balance_bytes} =
      Ethereumex.HttpClient.eth_call(%{
        data: "0x" <> abi_encoded_data,
        to: @registry_address
      })

    # Get the last 40 character from the address received.
    address = "0x" <> (balance_bytes |> String.slice((String.length(balance_bytes) - 40)..-1))
    ConCache.put(:contract_address_cache, contract, address)
    address
  end
end
