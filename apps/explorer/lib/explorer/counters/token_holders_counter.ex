defmodule Explorer.Counters.TokenHoldersCounter do
  use GenServer

  @moduledoc """
  Caches the number of token holders of a token.
  """

  alias Explorer.Chain.Address.TokenBalance
  alias Explorer.Repo

  @table :token_holders_counter

  def table_name do
    @table
  end

  @doc """
  Starts a process to periodically update the counter of the token holders.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Server
  @impl true
  def init(args) do
    create_table()

    Task.start_link(&consolidate/0)

    schedule_next_consolidation()

    {:ok, args}
  end

  def create_table do
    opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    :ets.new(table_name(), opts)
  end

  @doc """
  Consolidates the token holders info, by inserting or updating the `:ets` table with the current database information.
  """
  def consolidate do
    token_holders = Repo.all(TokenBalance.tokens_grouped_by_number_of_holders())

    for {token_hash, total} <- token_holders do
      insert_or_update_counter(token_hash, total)
    end
  end

  @doc """
  Fetches the token holders info for a specific token from the `:ets` table.
  """
  def fetch(token_hash) do
    do_fetch(:ets.lookup(table_name(), to_string(token_hash)))
  end

  defp do_fetch([{_, result}]), do: result
  defp do_fetch([]), do: 0

  @doc """
  Inserts a new item into the `:ets` table.

  When the record exists, the counter will be incremented by `number`. When the
  record does not exist, the counter will be inserted with a default value.
  """
  def insert_or_update_counter(token_hash, number) do
    default = {to_string(token_hash), 0}

    :ets.update_counter(table_name(), to_string(token_hash), number, default)
  end

  defp schedule_next_consolidation do
    config = Application.get_env(:explorer, Explorer.Counters.TransactionCounter)

    if Keyword.get(config, :enable_scheduling) do
      # every 30 minutes
      Process.send_after(self(), :consolidate, 30 * 60 * 1000)
    end
  end

  @impl true
  def handle_info(:consolidate, state) do
    Task.start_link(&consolidate/0)

    schedule_next_consolidation()

    {:noreply, state}
  end
end
