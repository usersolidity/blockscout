defmodule WalletApi.Utils do
  @moduledoc """
    1. Utils module for getting comments from input
    2. Gets the attestation and escrow contract address from registry
  """
  alias ABI.TypeDecoder
  alias Ethereumex.HttpClient
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
          |> TypeDecoder.decode(%ABI.FunctionSelector{
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

  defp get_address_from_registry(contract) do
    abi_data = ABI.encode("getAddressForString(string)", [contract])
    abi_encoded_data = abi_data |> Base.encode16(case: :lower)

    {:ok, balance_bytes} =
      HttpClient.eth_call(%{
        data: "0x" <> abi_encoded_data,
        to: @registry_address
      })

    # Get the last 40 character from the address received.
    address = "0x" <> (balance_bytes |> String.slice((String.length(balance_bytes) - 40)..-1))
    ConCache.put(:contract_address_cache, contract, address)
    address
  end

  def get_contract_address(contract) do
    address_from_cache = ConCache.get(:contract_address_cache, contract)

    if address_from_cache == nil do
      get_address_from_registry(contract)
    else
      address_from_cache
    end
  end
end
