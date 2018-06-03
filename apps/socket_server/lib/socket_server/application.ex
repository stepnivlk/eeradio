defmodule SocketServer.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {SocketServer.StreamSupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: SocketServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
