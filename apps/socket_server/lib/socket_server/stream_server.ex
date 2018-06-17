defmodule SocketServer.StreamServer do
  @moduledoc false

  alias SocketServer.StreamSupervisor
  alias SocketServer.Commands
  alias SocketServer.Utils
  alias SocketServer.Buffer
  alias Bolt.Sips
  alias Repository.Repo

  use GenServer

  @queue_size 10
  @history_size 10

  defstruct socket: nil,
            repo_conn: nil,
            current_song: nil,
            history: [],
            queue: [],
            commands: %Commands{},
            buffer_pid: nil

  def start_link(socket), do: GenServer.start_link(__MODULE__, socket)

  def init(socket) do
    GenServer.cast(self(), :accept)
    {:ok, %__MODULE__{socket: socket}}
  end

  # Incoming stream request from client
  def handle_info(
        {:tcp, _port, request},
        state = %{socket: accept_socket, repo_conn: repo_conn}
      ) do
    commands = request |> Commands.from_request()
    {:ok, buffer_pid} = Buffer.start_link(commands)

    :gen_tcp.send(accept_socket, [Utils.init_response()])

    GenServer.cast(self(), :play_songs)
    {:noreply, %{state | commands: commands, buffer_pid: buffer_pid}}
  end

  @doc ~S"""
  Called from the init
  Waits for client conn, when appeares starts buffer
  """
  def handle_cast(:accept, state = %{socket: listen_socket, commands: commands}) do
    repo_conn = Sips.conn()

    {:ok, accept_socket} = :gen_tcp.accept(listen_socket)
    StreamSupervisor.start_child()

    # {:noreply, %{state | socket: accept_socket, repo_conn: repo_conn, buffer_pid: buffer_pid}}
    {:noreply, %{state | socket: accept_socket, repo_conn: repo_conn }}
  end

  def handle_cast(:play_songs, state = %{socket: socket, buffer_pid: buffer_pid}) do
    case Buffer.request_chunk(buffer_pid) do
      {:ok, chunk, song} ->
        deliver_chunk(chunk, song, socket)
      _ ->
        :noop
    end

    GenServer.cast(self(), :play_songs)

    {:noreply, state}
  end

  defp deliver_chunk(chunk, song, socket) do
    header = Utils.make_header(song)

    case :gen_tcp.send(socket, [chunk, header]) do
      :ok -> true
      {:error, :closed} -> exit(:player_closed)
    end
  end

  # useless

  def handle_cast(
        {:mark_song, current_song},
        state = %{uid: uid, repo_conn: repo_conn}
      ) do
    Repo.mark_song_for_user(repo_conn, current_song, uid)

    {:noreply, state}
  end

  defp songs_from_preferences(repo_conn, preferences, []) do
    Repo.songs_from_preferences(repo_conn, preferences)
  end

  defp songs_from_preferences(_repo_conn, _preferences, queue), do: queue
end
