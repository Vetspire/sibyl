defmodule Sibyl.MixProject do
  use Mix.Project

  def project do
    [
      app: :sibyl,
      version: "0.1.4",
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
      ],
      name: "Sibyl",
      package: package(),
      description: description(),
      source_url: "https://github.com/vetspire/sibyl",
      homepage_url: "https://github.com/vetspire/sibyl",
      docs: [
        main: "Sibyl"
      ]
    ]
  end

  def application do
    [
      mod: {Sibyl.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp description() do
    """
    Sibyl is a library which augments the BEAM's default tracing capabilities by hooking
    into `:telemetry`, `:dbg` (the BEAM's built in tracing and debugging functionality),
    and `OpenTelemetry`.
    """
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/vetspire/sibyl"}
    ]
  end

  defp deps do
    [
      # Sibyl's actual dependencies
      {:jason, "~> 1.3"},
      {:decorator, "~> 1.2"},
      {:opentelemetry, "~> 1.0"},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_telemetry, "~> 1.0"},
      {:opentelemetry_process_propagator, "~> 0.1.0"},
      {:telemetry, "~> 1.0"},

      # Runtime dependencies for tests / linting
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev},
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
