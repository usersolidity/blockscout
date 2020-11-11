defmodule WalletApi.ExchangeRateApiTest do
  use WalletApi.ConnCase
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  @success_result %{
    "success" => true,
    "date" => "2020-11-04",
    "timestamp" => 1_107_302_399,
    "source" => "USD",
    "quotes" => %{
      "USDMXN" => 20.0
    }
  }

  describe "ExchangeRateApiTest" do
    test "should retrieve exchange rates for given currency" do
      ExchangeRateMock
      |> expect(:query_exchange_rate, fn _, _, _ ->
        @success_result
      end)

      response = WalletApi.CurrencyConversion.ExchangeRateAPI.get_exchange_rate("USD", "MXN", nil)
      assert Decimal.equal?(Decimal.from_float(20.0), response)
    end

    test "should throw when requesting an invalid currency code" do
      ExchangeRateMock
      |> expect(:query_exchange_rate, fn _, _, _ ->
        @success_result
      end)

      response = WalletApi.CurrencyConversion.ExchangeRateAPI.get_exchange_rate("USD", "ABC", nil)
      assert {:error, :not_found} == response
    end
  end
end
