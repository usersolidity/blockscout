defmodule WalletApi.CurrencyConversion.ExchangeRateAPI do
  @moduledoc """
   get exchange rate from currency layer API
  """
  alias WalletApi.DisplayError
  @api_url Application.fetch_env!(:walletapi, :exchange_rates_api)
  # 12 hours
  @min_ttl 12 * 60 * 60
  # behavior added to mock query_exchange_rate() for testing.
  @behaviour WalletAPI.Resolver.CurrencyConversion.ExchangeRateBehaviour
  require Logger

  def get_exchange_rate_behaviour, do: Application.get_env(:walletapi, :exchange_rate_behaviour)

  defp get_quotes({:error, :not_found}, _timestamp), do: {:error, :not_found}

  defp get_quotes(response, pair) do
    case response["quotes"][pair] do
      nil -> {:error, :not_found}
      _ -> Decimal.from_float(response["quotes"][pair])
    end
  end

  def get_exchange_rate(source_currency_code, currency_code, timestamp) do
    if(!currency_code) do
      raise DisplayError, message: "No currency code specified"
    end

    pair = source_currency_code <> currency_code
    response = get_exchange_rate_behaviour().query_exchange_rate(source_currency_code, currency_code, timestamp)
    get_quotes(response, pair)
  end

  def query_exchange_rate(source_currency_code, _currency_code, timestamp) do
    time_in_ms =
      if timestamp === nil do
        DateTime.utc_now()
      else
        DateTime.from_unix!(timestamp, :millisecond)
      end

    # is08601 format : YYYY-MM-DD
    date = Date.to_iso8601(time_in_ms)
    get_data(source_currency_code, time_in_ms, date)
  end

  defp get_data(source_currency_code, time_in_ms, date) do
    # global_ttl set to 1 year to store historical exchange rates
    # *****************TODO******************
    # Concache is in-memory cache and gets reset if the pod is cleaned
    # Add another cache layer (GoogleCloud Cache) to store the values
    # If in-memory cache is cleaned, get the rates from GoogleCloudCache
    # Sequence : ConCache (cache miss)-> GoogleCloudCache (cache miss)-> CurrencyLayerAPI
    # ***************************************
    data_from_cache = ConCache.get(:exchange_rate_cache, source_currency_code <> "-" <> date)

    # cache miss get the data from the api
    if data_from_cache == nil do
      get_data_from_api(source_currency_code, time_in_ms, date)
    else
      data_from_cache
    end
  end

  defp return_response(source_currency_code, time_in_ms, date, response) do
    if Map.get(response, "success") == false do
      IO.puts("Failed to fetch Exchange Rates")
      Logger.error(fn -> "Failed to fetch Exchange Rates: #{inspect(response)}" end)
      {:error, :not_found}
    else
      key = source_currency_code <> "-" <> date
      # if given time within last 24 hours - cache response for 12 hours by overriding default ttl.
      if DateTime.diff(DateTime.utc_now(), time_in_ms) < 24 * 60 * 60 do
        ConCache.put(:exchange_rate_cache, key, %ConCache.Item{value: response, ttl: @min_ttl})
      else
        ConCache.put(:exchange_rate_cache, key, response)
      end

      response
    end
  end

  defp get_data_from_api(source_currency_code, time_in_ms, date) do
    path = "/historical?"
    access_key = System.get_env("CURRENCY_LAYER_ACCESS_KEY")
    req_body = URI.encode_query(access_key: access_key, source: source_currency_code, date: date)

    case HTTPoison.get(@api_url <> path <> req_body) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        response = Poison.decode!(body)
        return_response(source_currency_code, time_in_ms, date, response)

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}
    end
  end
end
