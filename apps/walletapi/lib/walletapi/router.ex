defmodule WalletApi.Router do
  use WalletApi, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :graphql do
    plug(WalletApi.Plug.Context)
  end

  pipeline :graphiql do
    plug(WalletApi.Plug.Context)
  end

  scope "/api", WalletApi do
    pipe_through(:api)
  end

  scope "/" do
    pipe_through(:graphql)

    forward("/walletapi", Absinthe.Plug,
      context: %{pubsub: WalletApi.Endpoint},
      schema: WalletApi.Schema
    )

    pipe_through(:graphiql)

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: WalletApi.Schema,
      interface: :advanced,
      context: %{pubsub: WalletApi.Endpoint}
    )
  end
end
