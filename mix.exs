defmodule Prolink.MixProject do
  use Mix.Project

  def project do
    [
      app: :prolink,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Prolink.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:map_diff, "~> 1.3"}
    ]
  end
end
