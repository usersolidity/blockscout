defmodule WalletApi.Utils do
  @moduledoc """
    1. Utils module for getting comments from input
    2. Gets the attestation and escrow contract address from registry
  """
  alias ABI.TypeDecoder
  @forno_url Application.fetch_env!(:walletapi, :forno_url)
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
    functions = [
      %{contract_address: @registry_address, function_name: "getAddressForString", args: [contract]}
    ]

    json_arguments = [
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        url: @forno_url,
        http_options: [recv_timeout: :timer.minutes(1), timeout: :timer.minutes(1), hackney: [pool: :ethereum_jsonrpc]]
      ],
      variant: EthereumJSONRPC.Geth
    ]

    abi = [
      %{
        "constant" => true,
        "inputs" => [%{"internalType" => "string", "name" => "identifier", "type" => "string"}],
        "name" => "getAddressForString",
        "outputs" => [%{"internalType" => "address", "name" => "", "type" => "address"}],
        "payable" => false,
        "stateMutability" => "view",
        "type" => "function"
      }
    ]

    [{:ok, [contract_address]}] =
      EthereumJSONRPC.execute_contract_functions(
        functions,
        abi,
        json_arguments
      )

    # Get the last 40 character from the address received.
    address = "0x" <> (contract_address |> Base.encode16() |> String.downcase())
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
