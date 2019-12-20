defmodule Certstream.Mixfile do
  use Mix.Project

  def project do
    [
      app: :certstream,
      version: "1.1.2",
      elixir: "~> 1.6",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test]
    ]
  end

  def application do
    [
      extra_applications: [:honeybadger, :logger],
      mod: {Certstream, []},
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:cowboy, "~> 2.2"},
      {:pobox, "~> 1.0.2"},
      {:number, "~> 0.5.5"},
      {:easy_ssl, "~> 1.1.0"},
      {:honeybadger, "~> 0.1"},
      {:credo, "~> 0.9.0-rc1", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: :test}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
