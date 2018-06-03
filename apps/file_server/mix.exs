defmodule FileServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :file_server,
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
      mod: {FileServer.Application, []}
    ]
  end

  defp deps do
    [
      {:erlp3tags, git: "git@github.com:segun/erlp3tags.git", branch: "master"},
      {:credo, "~> 0.9", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.18", only: [:dev], runtime: false}
    ]
  end
end
