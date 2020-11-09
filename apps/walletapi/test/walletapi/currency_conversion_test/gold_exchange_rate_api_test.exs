defmodule WalletApi.GoldExchangeRateApiTest do
  use WalletApi.ConnCase
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!
  @mock_data_cgld_cusd %{
    "-Lv5oAJU8dDHVfqXlKkE" => %{
      "exchangeRate" => "10.1",
      "timestamp" => 1575293596846,
    },
    "-Lv5qbL_oSvKQ_452ZHh" => %{
      "exchangeRate" => "10.2",
      "timestamp" => 1575294235753,
    },
    "-Lv5rRCAOhPJJqVmLiID" => %{
      "exchangeRate" => "10.3",
      "timestamp" => 1575294452181,
    },
  }

  @mock_data_cusd_cgld %{
    "-Lv5oAJVzoRhZw3fiViQ" => %{
      "exchangeRate" => "0.1",
      "timestamp" => 1575293596846,
    },
    "-Lv5qbLcXmDPMJC5bnSk" => %{
      "exchangeRate" => "0.2",
      "timestamp" => 1575294235753,
    },
    "-Lv5rRCDdh-73eP0jArN" => %{
      "exchangeRate" => "0.3",
      "timestamp" => 1575294452181,
    },
  }

  describe "goldExchangeRateApiTest" do
    test "should retrieve the closest exchange rate for cGLD/cUSD" do
      ExchangeRateMock |> expect(:query_exchange_rate, fn(_,_, _) ->
        @mock_data_cgld_cusd
      end)

      response = WalletApi.CurrencyConversion.GoldExchangeRateAPI.get_exchange_rate("cGLD", "cUSD", 1575294235653)
      assert Decimal.equal?(Decimal.from_float(10.2), response)
    end

    test "should retrieve the closest exchange rate for cUSD/cGLD" do
      ExchangeRateMock |> expect(:query_exchange_rate, fn(_,_, _) ->
        @mock_data_cusd_cgld
      end)

      response = WalletApi.CurrencyConversion.GoldExchangeRateAPI.get_exchange_rate("cUSD", "cGLD", 1575294235653)
      assert Decimal.equal?(Decimal.from_float(0.2), response)
    end

    test "should throw when requesting an invalid currency code" do
      ExchangeRateMock |> expect(:query_exchange_rate, fn(_,_, _) ->
        {:error, :not_found }
      end)

      response = WalletApi.CurrencyConversion.GoldExchangeRateAPI.get_exchange_rate("cUSD", "ABC", 1575294235653)
      assert {:error, :not_found } == response
    end

  end

end
