defmodule WalletApi.CurrencyConversion.CurrencyConversionAPI do

  alias WalletApi.CurrencyConversion.ExchangeRateAPI
  alias WalletApi.CurrencyConversion.GoldExchangeRateAPI

  def get_exchange_rate(_, args, _) do
    from_code = Map.get(args, :source_currency_code, "USD")
    to_code = Map.get(args, :currency_code)
    timestamp = Map.get(args, :timestamp, nil)
    implied_exchange_rates = Map.get(args, :implied_exchange_rates, nil)
    steps = get_conversion_steps(from_code, to_code)

    #Run asynchronous tasks to get the exchange rates.
    if(Enum.count(steps) > 0) do
      tasks = for i <- 1..(Enum.count(steps)-1) do
        Task.async(fn ->
          prev_code = Enum.at(steps, i-1)
          to_code = Enum.at(steps, i)
          get_supported_exchange_rate(prev_code, to_code, timestamp, implied_exchange_rates)
        end)
      end
      tasks = Task.yield_many(tasks, 5000)
      rates = Enum.map(tasks, fn {task, res} ->
        if(res === nil) do
          Task.shutdown(task, :brutal_kill)
          nil
        else
          #Check Return Status. If status == exit then task failed
          {status, _} = res
          cond do
            status == :exit -> nil
            status == :ok -> res
          end
        end
      end)

      if(Enum.member?(rates, nil)) do
        {:error, "Unable to fetch all Exchange rates"}
      else
        #Multiply rates of all steps to get the final exchange rate
        rate = Enum.reduce(rates, Decimal.new(1), fn({:ok, rate}, acc) -> Decimal.mult(rate, acc) end)
        {:ok, %{:rate => rate}}
      end
    else
      {:ok, %{}}
    end
  end

  #Get conversion steps given the data we have today
  #Going from cGLD to local currency (or vice versa) is currently assumed to be the same as cGLD -> cUSD -> USD -> local currency.
  #And similar to cUSD to local currency, but with one less step.
  defp get_conversion_steps(from_code, to_code) do
    cond do
      from_code === to_code -> [] #Same code, nothing to do
      from_code === "cGLD" || to_code === "cGLD" ->
        cond do
          #cGLD -> X (where X !== cUSD)
          from_code === "cGLD" && to_code !== "cUSD" -> ["cGLD", "cUSD" | if(to_code !== "USD") do ["USD", to_code] else [to_code] end]
          #X -> cGLD (where X !== cUSD)
          from_code !== "cUSD" && to_code === "cGLD" -> [from_code | if(from_code !== "USD") do ["USD", "cUSD", "cGLD"] else ["cUSD", "cGLD"] end]
          true -> [from_code, to_code]
        end
      #cUSD -> X (where X !== USD)
      from_code === "cUSD" && to_code !== "USD" -> ["cUSD", "USD", to_code]
      #X -> cUSD (where X !== USD)
      from_code !== "USD" && to_code === "cUSD" -> [from_code, "USD", "cUSD"]
      true -> [from_code, to_code]
    end
  end

  defp get_supported_exchange_rate(from_code, to_code, timestamp, implied_exchange_rate) do
    pair = from_code <>"/"<>to_code
    cond do
      implied_exchange_rate && implied_exchange_rate[pair] -> implied_exchange_rate[pair]
      pair === "cUSD/USD" || pair === "USD/cUSD" -> Decimal.from_float(1.0)
      pair === "cGLD/cUSD" || pair === "cUSD/cGLD" -> GoldExchangeRateAPI.get_exchange_rate(from_code, to_code, timestamp)
      true -> ExchangeRateAPI.get_exchange_rate(from_code, to_code, timestamp)
    end
  end

end
