defmodule Repository.MixProject do
  use Mix.Project

  def project do
    [
      app: :repository,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      applications: [:bolt_sips],
      mod: {Repository.Application, []}
    ]
  end

  defp deps do
    [
      {:bolt_sips, "~> 0.4.12"},
      {:ecto, "~> 2.2"},
      {:postgrex, "~> 0.13"}
    ]
  end
end
