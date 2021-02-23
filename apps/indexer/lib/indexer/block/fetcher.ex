defmodule Indexer.Block.Fetcher do
  @moduledoc """
  Fetches and indexes block ranges.
  """

  use Spandex.Decorators

  require Logger

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.{Blocks, FetchedBeneficiaries}
  alias Explorer.Market
  alias Explorer.Chain.{Address, Block, Hash, Import, Transaction}
  alias Explorer.Chain.Cache.Blocks, as: BlocksCache
  alias Explorer.Chain.Cache.{Accounts, BlockNumber, Transactions, Uncles}
  alias Indexer.Block.Fetcher.Receipts

  alias Explorer.Celo.Util

  alias Indexer.Fetcher.{
    BlockReward,
    CeloAccount,
    CeloValidator,
    CeloValidatorGroup,
    CeloValidatorHistory,
    CeloVoterRewards,
    CeloVoters,
    CoinBalance,
    ContractCode,
    InternalTransaction,
    ReplacedTransaction,
    #    StakingPools,
    Token,
    TokenBalance,
    TokenInstance,
    UncleBlock
  }

  alias Indexer.Tracer

  alias Indexer.Transform.{
    AddressCoinBalances,
    Addresses,
    AddressTokenBalances,
    CeloAccounts,
    MintTransfers,
    TokenTransfers
  }

  alias Indexer.Transform.Blocks, as: TransformBlocks

  @type address_hash_to_fetched_balance_block_number :: %{String.t() => Block.block_number()}

  @type t :: %__MODULE__{}

  @doc """
  Calculates the balances and internal transactions and imports those with the given data.
  """
  @callback import(
              t,
              %{
                address_hash_to_fetched_balance_block_number: address_hash_to_fetched_balance_block_number,
                addresses: Import.Runner.options(),
                address_coin_balances: Import.Runner.options(),
                address_token_balances: Import.Runner.options(),
                blocks: Import.Runner.options(),
                block_second_degree_relations: Import.Runner.options(),
                block_rewards: Import.Runner.options(),
                broadcast: term(),
                logs: Import.Runner.options(),
                token_transfers: Import.Runner.options(),
                tokens: Import.Runner.options(),
                transactions: Import.Runner.options(),
                celo_accounts: Import.Runner.options()
              }
            ) :: Import.all_result()

  # These are all the *default* values for options.
  # DO NOT use them directly in the code.  Get options from `state`.

  @receipts_batch_size 250
  @receipts_concurrency 10

  @doc false
  def default_receipts_batch_size, do: @receipts_batch_size

  @doc false
  def default_receipts_concurrency, do: @receipts_concurrency

  @enforce_keys ~w(json_rpc_named_arguments)a
  defstruct broadcast: nil,
            callback_module: nil,
            json_rpc_named_arguments: nil,
            receipts_batch_size: @receipts_batch_size,
            receipts_concurrency: @receipts_concurrency

  @doc """
  Required named arguments

    * `:json_rpc_named_arguments` - `t:EthereumJSONRPC.json_rpc_named_arguments/0` passed to
        `EthereumJSONRPC.json_rpc/2`.

  The follow options can be overridden:

    * `:receipts_batch_size` - The number of receipts to request in one call to the JSONRPC.  Defaults to
      `#{@receipts_batch_size}`.  Receipt requests also include the logs for when the transaction was collated into the
      block.  *These logs are not paginated.*
    * `:receipts_concurrency` - The number of concurrent requests of `:receipts_batch_size` to allow against the JSONRPC
      **for each block range**.  Defaults to `#{@receipts_concurrency}`.  *Each transaction only has one receipt.*

  """
  def new(named_arguments) when is_map(named_arguments) do
    struct!(__MODULE__, named_arguments)
  end

  defp process_extra_logs(extra_logs) do
    e_logs =
      extra_logs
      |> Enum.filter(fn %{transaction_hash: tx_hash, block_hash: block_hash} ->
        tx_hash == block_hash
      end)
      |> Enum.map(fn log ->
        Map.put(log, :transaction_hash, nil)
      end)

    e_logs
  end

  defp add_celo_token_balances(celo_token, addresses, acc) do
    Enum.reduce(addresses, acc, fn
      %{fetched_coin_balance_block_number: bn, hash: hash}, acc ->
        MapSet.put(acc, %{address_hash: hash, token_contract_address_hash: celo_token, block_number: bn})

      _, acc ->
        acc
    end)
  end

  defp config(key) do
    Application.get_env(:indexer, __MODULE__, [])[key]
  end

  defp read_addresses do
    with {:ok, celo_token} <- Util.get_address("GoldToken"),
         {:ok, stable_token_usd} <- Util.get_address("StableToken"),
         {:ok, stable_token_eur} <- Util.get_address("StableTokenEUR"),
         {:ok, oracle_address} <- Util.get_address("SortedOracles") do
      tokens = %{
        celo: celo_token,
        cusd: stable_token_usd,
        ceur: stable_token_eur
      }

      {:ok, tokens, oracle_address}
    else
      err ->
        {:error, err}
    end
  end

  @decorate span(tracer: Tracer)
  @spec fetch_and_import_range(t, Range.t()) ::
          {:ok, %{inserted: %{}, errors: [EthereumJSONRPC.Transport.error()]}}
          | {:error,
             {step :: atom(), reason :: [%Ecto.Changeset{}] | term()}
             | {step :: atom(), failed_value :: term(), changes_so_far :: term()}}
  def fetch_and_import_range(
        %__MODULE__{
          broadcast: _broadcast,
          callback_module: callback_module,
          json_rpc_named_arguments: json_rpc_named_arguments
        } = state,
        _..last_block = range
      )
      when callback_module != nil do
    with {:blocks,
          {:ok,
           %Blocks{
             blocks_params: blocks_params,
             transactions_params: transactions_params_without_receipts,
             block_second_degree_relations_params: block_second_degree_relations_params,
             errors: blocks_errors
           }}} <- {:blocks, EthereumJSONRPC.fetch_blocks_by_range(range, json_rpc_named_arguments)},
         blocks = TransformBlocks.transform_blocks(blocks_params),
         {:ok, %{logs: extra_logs}} <- EthereumJSONRPC.fetch_logs(range, json_rpc_named_arguments),
         {:receipts, {:ok, receipt_params}} <- {:receipts, Receipts.fetch(state, transactions_params_without_receipts)},
         %{logs: tx_logs, receipts: receipts} = receipt_params,
         logs = tx_logs ++ process_extra_logs(extra_logs),
         transactions_with_receipts = Receipts.put(transactions_params_without_receipts, receipts),
         %{token_transfers: normal_token_transfers, tokens: normal_tokens} = TokenTransfers.parse(logs),
         celo_token_enabled = config(:enable_gold_token),
         {:ok,
          tokens = %{
            celo: celo_token,
            cusd: stable_token_usd,
            ceur: stable_token_eur
          },
          oracle_address} <-
           (if celo_token_enabled do
              read_addresses()
            else
              {:ok, nil, nil}
            end),
         %{token_transfers: celo_token_transfers} =
           (if celo_token_enabled do
              TokenTransfers.parse_tx(transactions_with_receipts, celo_token)
            else
              %{token_transfers: []}
            end),
         # Non CELO fees should be handled by events
         %{
           accounts: celo_accounts,
           validators: celo_validators,
           validator_groups: celo_validator_groups,
           voters: celo_voters,
           signers: signers,
           attestations_fulfilled: attestations_fulfilled,
           attestations_requested: attestations_requested,
           exchange_rates: exchange_rates,
           account_names: account_names,
           voter_rewards: celo_voter_rewards,
           wallets: celo_wallets
         } = CeloAccounts.parse(logs, oracle_address),
         market_history =
           exchange_rates
           |> Enum.filter(fn el -> el.token == stable_token_usd end)
           |> Enum.filter(fn el -> el.rate > 0 end)
           |> Enum.map(fn %{rate: rate, stamp: time} ->
             inv_rate = Decimal.from_float(1 / rate)
             date = DateTime.to_date(DateTime.from_unix!(time))
             %{opening_price: inv_rate, closing_price: inv_rate, date: date}
           end),
         exchange_rates =
           (if Enum.count(exchange_rates) > 0 and celo_token != nil do
              [%{token: celo_token, rate: 1.0} | exchange_rates]
            else
              []
            end),
         %{mint_transfers: mint_transfers} = MintTransfers.parse(logs),
         %FetchedBeneficiaries{params_set: beneficiary_params_set, errors: beneficiaries_errors} =
           fetch_beneficiaries(blocks, json_rpc_named_arguments),
         tokens =
           normal_tokens ++
             (if celo_token_enabled do
                [%{contract_address_hash: celo_token, type: "ERC-20"}]
              else
                []
              end),
         token_transfers = normal_token_transfers ++ celo_token_transfers,
         addresses =
           Addresses.extract_addresses(%{
             block_reward_contract_beneficiaries: MapSet.to_list(beneficiary_params_set),
             blocks: blocks,
             logs: logs,
             mint_transfers: mint_transfers,
             token_transfers: token_transfers,
             transactions: transactions_with_receipts,
             wallets: celo_wallets,
             # The address of the CELO token has to be added to the addresses table
             celo_token:
               if celo_token_enabled do
                 [%{hash: celo_token, block_number: last_block}]
               else
                 []
               end
           }),
         celo_transfers =
           normal_token_transfers
           |> Enum.filter(fn %{token_contract_address_hash: contract} -> contract == celo_token end),
         coin_balances_params_set =
           %{
             beneficiary_params: MapSet.to_list(beneficiary_params_set),
             blocks_params: blocks,
             logs_params: logs,
             celo_transfers: celo_transfers,
             transactions_params: transactions_with_receipts
           }
           |> AddressCoinBalances.params_set(),
         beneficiaries_with_gas_payment <-
           beneficiary_params_set
           |> add_gas_payments(transactions_with_receipts)
           |> BlockReward.reduce_uncle_rewards(),
         address_token_balances_from_transfers =
           AddressTokenBalances.params_set(%{token_transfers_params: token_transfers}),
         # Also update the CELO token balances
         address_token_balances =
           (if celo_token_enabled do
              add_celo_token_balances(celo_token, addresses, address_token_balances_from_transfers)
            else
              address_token_balances_from_transfers
            end),
         {:ok, inserted} <-
           __MODULE__.import(
             state,
             %{
               addresses: %{params: addresses},
               address_coin_balances: %{params: coin_balances_params_set},
               address_token_balances: %{params: address_token_balances},
               blocks: %{params: blocks},
               block_second_degree_relations: %{params: block_second_degree_relations_params},
               block_rewards: %{errors: beneficiaries_errors, params: beneficiaries_with_gas_payment},
               logs: %{params: logs},
               account_names: %{params: account_names},
               celo_signers: %{params: signers},
               token_transfers: %{params: token_transfers},
               tokens: %{params: tokens},
               transactions: %{params: transactions_with_receipts},
               exchange_rate: %{params: exchange_rates},
               wallets: %{params: celo_wallets}
             }
           ) do
      result = {:ok, %{inserted: inserted, errors: blocks_errors}}

      accounts = Enum.uniq(celo_accounts ++ attestations_fulfilled ++ attestations_requested)

      async_import_celo_accounts(%{
        celo_accounts: %{params: accounts, requested: attestations_requested, fulfilled: attestations_fulfilled}
      })

      Market.bulk_insert_history(market_history)

      async_import_celo_validators(%{celo_validators: %{params: celo_validators}})
      async_import_celo_voter_rewards(%{celo_voter_rewards: %{params: celo_voter_rewards}})
      async_import_celo_validator_groups(%{celo_validator_groups: %{params: celo_validator_groups}})
      async_import_celo_voters(%{celo_voters: %{params: celo_voters}})
      async_import_celo_validator_history(range)

      update_block_cache(inserted[:blocks])
      update_transactions_cache(inserted[:transactions])
      update_addresses_cache(inserted[:addresses])
      update_uncles_cache(inserted[:block_second_degree_relations])
      result
    else
      {step, {:error, reason}} -> {:error, {step, reason}}
      {step, :error} -> {:error, {step, "Unknown error"}}
      {:import, {:error, step, failed_value, changes_so_far}} -> {:error, {step, failed_value, changes_so_far}}
    end
  end

  defp update_block_cache([]), do: :ok

  defp update_block_cache(blocks) when is_list(blocks) do
    {min_block, max_block} = Enum.min_max_by(blocks, & &1.number)

    BlockNumber.update_all(max_block.number)
    BlockNumber.update_all(min_block.number)
    BlocksCache.update(blocks)
  end

  defp update_block_cache(_), do: :ok

  defp update_transactions_cache(transactions) do
    Transactions.update(transactions)
  end

  defp update_addresses_cache(addresses), do: Accounts.drop(addresses)

  defp update_uncles_cache(updated_relations) do
    Uncles.update_from_second_degree_relations(updated_relations)
  end

  def import(
        %__MODULE__{broadcast: broadcast, callback_module: callback_module} = state,
        options
      )
      when is_map(options) do
    {address_hash_to_fetched_balance_block_number, import_options} =
      pop_address_hash_to_fetched_balance_block_number(options)

    options_with_broadcast =
      Map.merge(
        import_options,
        %{
          address_hash_to_fetched_balance_block_number: address_hash_to_fetched_balance_block_number,
          broadcast: broadcast
        }
      )

    callback_module.import(state, options_with_broadcast)
  end

  def async_import_token_instances(%{token_transfers: token_transfers}) do
    TokenInstance.async_fetch(token_transfers)
  end

  def async_import_token_instances(_), do: :ok

  def async_import_block_rewards([]), do: :ok

  def async_import_block_rewards(errors) when is_list(errors) do
    errors
    |> block_reward_errors_to_block_numbers()
    |> BlockReward.async_fetch()
  end

  def async_import_coin_balances(%{addresses: addresses}, %{
        address_hash_to_fetched_balance_block_number: address_hash_to_block_number
      }) do
    addresses
    |> Enum.map(fn %Address{hash: address_hash} ->
      block_number = Map.fetch!(address_hash_to_block_number, to_string(address_hash))
      %{address_hash: address_hash, block_number: block_number}
    end)
    |> CoinBalance.async_fetch_balances()
  end

  def async_import_coin_balances(_, _), do: :ok

  def async_import_created_contract_codes(%{transactions: transactions}) do
    transactions
    |> Enum.flat_map(fn
      %Transaction{
        block_number: block_number,
        hash: hash,
        created_contract_address_hash: %Hash{} = created_contract_address_hash,
        created_contract_code_indexed_at: nil
      } ->
        [%{block_number: block_number, hash: hash, created_contract_address_hash: created_contract_address_hash}]

      %Transaction{created_contract_address_hash: nil} ->
        []
    end)
    |> ContractCode.async_fetch(10_000)
  end

  def async_import_created_contract_codes(_), do: :ok

  def async_import_internal_transactions(%{blocks: blocks}) do
    blocks
    |> Enum.map(fn %Block{number: block_number} -> block_number end)
    |> InternalTransaction.async_fetch(10_000)
  end

  def async_import_internal_transactions(_), do: :ok

  def async_import_tokens(%{tokens: tokens}) do
    tokens
    |> Enum.map(& &1.contract_address_hash)
    |> Token.async_fetch()
  end

  def async_import_tokens(_), do: :ok

  def async_import_token_balances(%{address_token_balances: token_balances}) do
    TokenBalance.async_fetch(token_balances)
  end

  def async_import_token_balances(_), do: :ok

  def async_import_celo_accounts(%{celo_accounts: accounts}) do
    CeloAccount.async_fetch(accounts)
  end

  def async_import_celo_accounts(_), do: :ok

  def async_import_celo_validators(%{celo_validators: accounts}) do
    CeloValidator.async_fetch(accounts)
  end

  def async_import_celo_validators(_), do: :ok

  def async_import_celo_validator_history(range) do
    CeloValidatorHistory.async_fetch(range)
  end

  def async_import_celo_validator_groups(%{celo_validator_groups: accounts}) do
    CeloValidatorGroup.async_fetch(accounts)
  end

  def async_import_celo_validator_groups(_), do: :ok

  def async_import_celo_voter_rewards(%{celo_voter_rewards: accounts}) do
    CeloVoterRewards.async_fetch(accounts)
  end

  def async_import_celo_voters(%{celo_voters: accounts}) do
    CeloVoters.async_fetch(accounts)
  end

  def async_import_celo_voters(_), do: :ok

  def async_import_uncles(%{block_second_degree_relations: block_second_degree_relations}) do
    UncleBlock.async_fetch_blocks(block_second_degree_relations)
  end

  def async_import_uncles(_), do: :ok

  def async_import_replaced_transactions(%{transactions: transactions}) do
    transactions
    |> Enum.flat_map(fn
      %Transaction{block_hash: %Hash{} = block_hash, nonce: nonce, from_address_hash: %Hash{} = from_address_hash} ->
        [%{block_hash: block_hash, nonce: nonce, from_address_hash: from_address_hash}]

      %Transaction{block_hash: nil} ->
        []
    end)
    |> ReplacedTransaction.async_fetch(10_000)
  end

  def async_import_replaced_transactions(_), do: :ok

  defp block_reward_errors_to_block_numbers(block_reward_errors) when is_list(block_reward_errors) do
    Enum.map(block_reward_errors, &block_reward_error_to_block_number/1)
  end

  defp block_reward_error_to_block_number(%{data: %{block_number: block_number}}) when is_integer(block_number) do
    block_number
  end

  defp block_reward_error_to_block_number(%{data: %{block_quantity: block_quantity}}) when is_binary(block_quantity) do
    quantity_to_integer(block_quantity)
  end

  defp fetch_beneficiaries(blocks, json_rpc_named_arguments) do
    hash_string_by_number =
      Enum.into(blocks, %{}, fn %{number: number, hash: hash_string}
                                when is_integer(number) and is_binary(hash_string) ->
        {number, hash_string}
      end)

    hash_string_by_number
    |> Map.keys()
    |> EthereumJSONRPC.fetch_beneficiaries(json_rpc_named_arguments)
    |> case do
      {:ok, %FetchedBeneficiaries{params_set: params_set} = fetched_beneficiaries} ->
        consensus_params_set = consensus_params_set(params_set, hash_string_by_number)

        %FetchedBeneficiaries{fetched_beneficiaries | params_set: consensus_params_set}

      {:error, reason} ->
        Logger.error(fn -> ["Could not fetch beneficiaries: ", inspect(reason)] end)

        error =
          case reason do
            %{code: code, message: message} -> %{code: code, message: message}
            _ -> %{code: -1, message: inspect(reason)}
          end

        errors =
          Enum.map(hash_string_by_number, fn {number, _} when is_integer(number) ->
            Map.put(error, :data, %{block_number: number})
          end)

        %FetchedBeneficiaries{errors: errors}

      :ignore ->
        %FetchedBeneficiaries{}
    end
  end

  defp consensus_params_set(params_set, hash_string_by_number) do
    params_set
    |> Enum.filter(fn %{block_number: block_number, block_hash: block_hash_string}
                      when is_integer(block_number) and is_binary(block_hash_string) ->
      case Map.fetch!(hash_string_by_number, block_number) do
        ^block_hash_string ->
          true

        other_block_hash_string ->
          Logger.debug(fn ->
            [
              "fetch beneficiaries reported block number (",
              to_string(block_number),
              ") maps to different (",
              other_block_hash_string,
              ") block hash than the one from getBlock (",
              block_hash_string,
              "). A reorg has occurred."
            ]
          end)

          false
      end
    end)
    |> Enum.into(MapSet.new())
  end

  defp add_gas_payments(beneficiaries, transactions) do
    transactions_by_block_number = Enum.group_by(transactions, & &1.block_number)

    Enum.map(beneficiaries, fn beneficiary ->
      case beneficiary.address_type do
        :validator ->
          gas_payment = gas_payment(beneficiary, transactions_by_block_number)

          "0x" <> minted_hex = beneficiary.reward
          {minted, _} = Integer.parse(minted_hex, 16)

          %{beneficiary | reward: minted + gas_payment}

        _ ->
          beneficiary
      end
    end)
  end

  defp gas_payment(transactions) when is_list(transactions) do
    transactions
    |> Stream.map(&(&1.gas_used * &1.gas_price))
    |> Enum.sum()
  end

  defp gas_payment(%{block_number: block_number}, transactions_by_block_number)
       when is_map(transactions_by_block_number) do
    case Map.fetch(transactions_by_block_number, block_number) do
      {:ok, transactions} -> gas_payment(transactions)
      :error -> 0
    end
  end

  # `fetched_balance_block_number` is needed for the `CoinBalanceFetcher`, but should not be used for `import` because the
  # balance is not known yet.
  defp pop_address_hash_to_fetched_balance_block_number(options) do
    {address_hash_fetched_balance_block_number_pairs, import_options} =
      get_and_update_in(options, [:addresses, :params, Access.all()], &pop_hash_fetched_balance_block_number/1)

    address_hash_to_fetched_balance_block_number = Map.new(address_hash_fetched_balance_block_number_pairs)

    {address_hash_to_fetched_balance_block_number, import_options}
  end

  defp pop_hash_fetched_balance_block_number(
         %{
           fetched_coin_balance_block_number: fetched_coin_balance_block_number,
           hash: hash
         } = address_params
       ) do
    {{hash, fetched_coin_balance_block_number}, Map.delete(address_params, :fetched_coin_balance_block_number)}
  end
end
