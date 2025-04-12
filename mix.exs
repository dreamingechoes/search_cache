defmodule SearchCache.MixProject do
  use Mix.Project

  def project do
    [
      app: :search_cache,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SearchCache.Application, []}
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.2"},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
