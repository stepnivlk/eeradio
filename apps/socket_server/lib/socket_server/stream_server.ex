defmodule SocketServer.StreamServer do
  @moduledoc false

  alias SocketServer.StreamSupervisor
  alias SocketServer.Commands

  use GenServer
  use SocketServer.Player

  defstruct socket: nil, uid: nil, port: nil, history: [], next_song: nil

  def start_link(socket), do: GenServer.start_link(__MODULE__, socket)

  def init(socket) do
    GenServer.cast(self(), :accept)
    {:ok, %__MODULE__{socket: socket}}
  end

  def handle_cast(:accept, %__MODULE__{socket: listen_socket}) do
    {:ok, accept_socket} = :gen_tcp.accept(listen_socket)
    IO.puts("StreamServer: new conn")
    StreamSupervisor.start_child()
    {:noreply, %__MODULE__{socket: accept_socket}}
  end

  def handle_info({:tcp, _port, request}, state = %__MODULE__{socket: accept_socket}) do
    commands = Commands.from_request(request)
    IO.inspect(commands)

    uid = Commands.uid(commands)
    IO.inspect(uid)

    port = Commands.port(commands)
    IO.inspect(port)

    :gen_tcp.send(accept_socket, [init_response()])

    play_songs(accept_socket, <<>>)

    {:noreply, %{state | uid: uid, port: port}}
  end

  defp init_response do
    [
      'ICY 200 OK\r\n',
      'icy-notice1: <BR>This stream requires',
      '<a href=\"http://www.winamp.com/\">Winamp</a><BR>\r\n',
      'icy-notice2: Elixir Shoutcast server<BR>\r\n',
      'icy-name: Erradio radio\r\n',
      'icy-genre: hard\r\n',
      'icy-url: http://localhost:3131/stepnivlk\r\n',
      'content-type: audio/mpeg\r\n',
      'icy-pub: 1\r\n',
      'icy-metaint: #{@chunksize}\r\n',
      'icy-br: 96\r\n\r\n'
    ]
  end
end
