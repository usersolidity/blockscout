Mox.defmock(GetTransactionBehaviorMock, for: WalletAPI.Resolver.TransactionResolver.GetTransactionBehavior)
Mox.defmock(ExchangeRateMock, for: WalletAPI.Resolver.CurrencyConversion.ExchangeRateBehaviour)

# Counter `test --no-start`.  `--no-start` is needed for `:indexer` compatibility
{:ok, _} = Application.ensure_all_started(:walletapi)
ExUnit.start()
