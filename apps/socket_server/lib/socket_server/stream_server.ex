defmodule SocketServer.StreamServer do
  @moduledoc false

  alias SocketServer.StreamSupervisor
  alias SocketServer.Commands
  alias SocketServer.Utils
  alias Bolt.Sips
  alias Repository.Repo

  use GenServer

  @chunksize 24_576
  @queue_size 10
  @history_size 10
  @base_dir "../data/"

  defstruct socket: nil,
            uid: nil,
            port: nil,
            repo_conn: nil,
            history: [],
            queue: [],
            buffer: <<>>,
            source: nil,
            header: nil,
            offset: nil,
            stop: nil,
            preferences: %{genre: "Downtempo"}

  def start_link(socket), do: GenServer.start_link(__MODULE__, socket)

  def init(socket) do
    GenServer.cast(self(), :accept)
    {:ok, %__MODULE__{socket: socket}}
  end

  def handle_cast(:accept, %__MODULE__{socket: listen_socket}) do
    repo_conn = Sips.conn()
    {:ok, accept_socket} = :gen_tcp.accept(listen_socket)
    StreamSupervisor.start_child()

    {:noreply, %__MODULE__{socket: accept_socket, repo_conn: repo_conn}}
  end

  def handle_info(
        {:tcp, _port, request},
        state = %__MODULE__{socket: accept_socket, repo_conn: repo_conn, preferences: preferences}
      ) do
    commands = Commands.from_request(request)

    uid = Commands.uid(commands)
    port = Commands.port(commands)

    queue = Repo.songs_from_preferences(repo_conn, preferences)

    :gen_tcp.send(accept_socket, [Utils.init_response()])

    GenServer.cast(self(), :play_songs)

    {:noreply, %{state | uid: uid, port: port, queue: queue}}
  end

  def handle_cast(:pop_song, state = %__MODULE__{queue: [song | rest], history: history}) do
    {:noreply, %{state | queue: rest, history: [song | rest]}}
  end

  def handle_cast(
        :play_songs,
        state = %__MODULE__{source: source, socket: socket, queue: [song | rest], buffer: buffer}
      ) do
    File.close(source)
    GenServer.cast(self(), :pop_song)
    IO.inspect(state)

    path = "#{@base_dir}/#{song.path}"
    {start, stop} = FileServer.Mp3Cues.find(path)
    header = Utils.make_header(song)

    {:ok, new_source} = File.open(path, [:read, :binary, :raw])
    GenServer.cast(self(), :send_file)

    {:noreply, %{state | source: new_source, header: header, offset: start, stop: stop}}
  end

  def handle_cast(
        :send_file,
        state = %__MODULE__{
          socket: socket,
          source: source,
          buffer: buffer,
          header: header,
          offset: offset,
          stop: stop
        }
      ) do
    need = @chunksize - byte_size(buffer)
    last = offset + need

    IO.inspect("send_file #{inspect(offset)} #{inspect(need)}")

    if last >= stop do
      max = stop - offset
      {:ok, bin} = :file.pread(source, offset, max)

      new_buffer = :erlang.list_to_binary([buffer, bin])

      GenServer.cast(self(), :play_songs)

      {:noreply, %{state | buffer: new_buffer}}
    else
      {:ok, bin} = :file.pread(source, offset, need)
      write_data(socket, buffer, bin, header)

      GenServer.cast(self(), :send_file)

      {:noreply, %{state | offset: offset + need, buffer: <<>>}}
    end
  end

  defp write_data(socket, buffer, bin, header) do
    case byte_size(buffer) + byte_size(bin) do
      @chunksize ->
        case :gen_tcp.send(socket, [buffer, bin, header]) do
          :ok -> true
          {:error, :closed} -> exit(:player_closed)
        end

      _other ->
        exit(:error) # TODO: handle properly
    end
  end
end
