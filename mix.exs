defmodule Sibyl.MixProject do
  use Mix.Project

  def project do
    [
      app: :sibyl,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: [:iex, :mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :race_conditions]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        lint: :test,
        dialyzer: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.watch": :test
      ]
    ]
  end

  def application do
    [
      mod: {Sibyl.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      # Sibyl's actual dependencies
      {:decorator, "~> 1.2"},
      {:opentelemetry, "~> 1.0"},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_telemetry, "~> 1.0"},
      {:telemetry, "~> 1.0"},
      # Runtime dependencies for tests / linting
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["coveralls.html --trace --slowest 10"],
      lint: [
        "format --check-formatted --dry-run",
        "credo --strict",
        "compile --warnings-as-errors",
        "dialyzer"
      ]
    ]
  end
end
