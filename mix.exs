defmodule Certstream.Mixfile do
  use Mix.Project

  def project do
    [
      app: :certstream,
      version: "1.4.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
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
      extra_applications: [:honeybadger, :logger],
      mod: {Certstream, []}
    ]
  end

  defp deps do
    [
      {:cowboy, "~> 2.7"},
      {:easy_ssl, "~> 1.1"},
      {:honeybadger, "~> 0.14"},
      {:httpoison, "~> 1.6"},
      {:instruments, "~> 1.1"},
      {:jason, "~> 1.2"},
      {:number, "~> 1.0"},
      {:pobox, "~> 1.2"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13", only: :test}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
