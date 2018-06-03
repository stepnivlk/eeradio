defmodule Repository.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Bolt.Sips, Application.get_env(:bolt_sips, Bolt)}
    ]

    opts = [strategy: :one_for_one, name: Repository.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
