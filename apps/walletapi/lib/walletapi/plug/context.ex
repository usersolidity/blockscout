defmodule WalletApi.Plug.Context do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    %Plug.Conn{body_params: body_params} = conn
    # Sets the localCurrencyCode as a context to be accessed in resolvers.
    local_currency = body_params["variables"]["localCurrencyCode"]

    context = %{
      :local_currency_code =>
        if local_currency do
          local_currency
        else
          "USD"
        end
    }

    # Absinthe.Plug calls Absinthe.run() with the options added to the `conn`.
    Absinthe.Plug.put_options(conn, context: context)
  end
end
