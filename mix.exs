defmodule Certstream.Mixfile do
  use Mix.Project

  def project do
    [
      app: :certstream,
      version: "1.0.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
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
      {:easy_ssl, "~> 1.0.2"},
      {:credo, "~> 0.9.0-rc1", only: [:dev, :test], runtime: false},
    ]
  end
end
