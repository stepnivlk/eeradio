defmodule SocketServer.StreamSupervisor do
  @moduledoc false
  use DynamicSupervisor

  alias SocketServer.StreamServer

  @port 3131

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    {:ok, listen_socket} = start_listen()
    spawn_link(&empty_listeners/0)
    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [listen_socket])
  end

  def start_child do
    stream_server_spec = %{
      id: StreamServer,
      restart: :temporary,
      start: {StreamServer, :start_link, []}
    }

    DynamicSupervisor.start_child(__MODULE__, stream_server_spec)
  end

  defp empty_listeners, do: for(_ <- 1..10, do: start_child())

  defp start_listen do
    :gen_tcp.listen(@port, [:binary, {:packet, 0}, {:reuseaddr, true}, {:active, :once}])
  end
end
