defmodule WalletApi.CurrencyConversion.GoldExchangeRateAPI do
  @moduledoc """
   get gold exchange rate from firebase database
  """
  alias WalletApi.DisplayError
  @database_url Application.fetch_env!(:walletapi, :firebase_database_url)
  # behavior added to mock query_exchange_rate() for testing.
  @behaviour WalletAPI.Resolver.CurrencyConversion.ExchangeRateBehaviour

  def get_exchange_rate_behaviour, do: Application.get_env(:walletapi, :gold_exchange_rate_behaviour)

  defp get_nearest_rate({:error, :not_found}, _timestamp), do: {:error, :not_found}

  defp get_nearest_rate(response, timestamp) do
    {_key, value} = response |> Enum.min_by(fn {_key, value} -> abs(Map.get(value, "timestamp") - timestamp) end)
    Decimal.new(Map.get(value, "exchangeRate"))
  end

  def get_exchange_rate(source_currency_code, currency_code, timestamp) do
    timestamp =
      if timestamp do
        timestamp
      else
        DateTime.to_unix(DateTime.utc_now(), :millisecond)
      end

    if(!currency_code) do
      raise DisplayError, message: "No currency code specified"
    end

    response = get_exchange_rate_behaviour().query_exchange_rate(source_currency_code, currency_code, timestamp)
    get_nearest_rate(response, timestamp)
  end

  def query_exchange_rate(source_currency_code, currency_code, timestamp) do
    pair = source_currency_code <> "/" <> currency_code
    # Firebase provides inbuilt api to access query response
    path = "exchangeRates/" <> pair <> ".json?"
    start_at = timestamp - 30 * 60 * 1000
    end_at = timestamp + 30 * 60 * 1000
    filters = ~s(orderBy="timestamp"&startAt=#{to_string(start_at)}&endAt=#{to_string(end_at)})

    complete_path = (@database_url <> path <> filters) |> String.replace("\\", "")

    case HTTPoison.get(complete_path) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        Poison.decode!(body)

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}
    end
  end
end
