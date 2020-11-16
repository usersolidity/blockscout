defmodule Walletapi.MixProject do
  use Mix.Project

  def project do
    [
      app: :walletapi,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      version: "0.0.1",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "A cloud service that stores and serves data about blockchain activity",
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: [:mix],
        ignore_warnings: "../../.dialyzer-ignore"
      ],
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      lockfile: "../../mix.lock",
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Walletapi.Application, []},
      extra_applications: [:logger, :runtime_tools, :con_cache]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.4.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:gettext, "~> 0.16.1"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:absinthe, "~> 1.4"},
      {:absinthe_plug,
       git: "https://github.com/ayrat555/absinthe_plug.git", branch: "ab-enable-default-query", override: true},
      {:absinthe_relay, "~> 1.4"},
      {:poison, "~> 3.1"},
      {:httpoison, "~> 1.0", override: true},
      {:ethereumex, "~> 0.6.0", override: true},
      {:ex_abi, github: "poanetwork/ex_abi", branch: "vb-3.0", override: true},
      {:explorer, in_umbrella: true},
      {:indexer, in_umbrella: true, runtime: false},
      {:ethereum_jsonrpc, in_umbrella: true},
      {:con_cache, "~> 0.13.1"},
      {:mox, "~> 0.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
