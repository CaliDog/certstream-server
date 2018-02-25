defmodule Ctlwatcher.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ctlwatcher,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.0"},
      {:poison, "~> 2.0"},
      {:credo, "~> 0.9.0-rc1", only: [:dev, :test], runtime: false},
    ]
  end
end
