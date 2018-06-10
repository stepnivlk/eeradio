defmodule SocketServer.StreamServer do
  @moduledoc false

  alias SocketServer.StreamSupervisor
  alias SocketServer.Commands
  alias SocketServer.Utils
  alias SocketServer.Buffer
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
            current_song: nil,
            history: [],
            # Upcoming songs
            queue: [],
            # Used when transitioning between songs
            buffer: <<>>,
            # Opened file
            source: nil,
            # To be sent to a client
            header: nil,
            # Current offset in a song
            offset: nil,
            # Where data ends in a song
            stop: nil,
            commands: %Commands{},
            preferences: %{genre: "Hardtekno", user_uid: "stepnivlk"},
            buffer_pid: nil

  def start_link(socket), do: GenServer.start_link(__MODULE__, socket)

  def init(socket) do
    GenServer.cast(self(), :accept)
    {:ok, %__MODULE__{socket: socket}}
  end

  def handle_info(
        {:tcp, _port, request},
        state = %__MODULE__{socket: accept_socket, repo_conn: repo_conn, preferences: preferences}
      ) do
    commands = request |> Commands.from_request() |> Commands.to_struct()

    {:ok, buffer_pid} = Buffer.start_link(commands)

    queue = songs_from_preferences(repo_conn, preferences, [])

    :gen_tcp.send(accept_socket, [Utils.init_response()])

    GenServer.cast(self(), :play_songs)

    {:noreply, %{state | commands: commands, queue: queue}}
  end

  def handle_cast(:accept, %__MODULE__{socket: listen_socket}) do
    repo_conn = Sips.conn()
    {:ok, accept_socket} = :gen_tcp.accept(listen_socket)
    StreamSupervisor.start_child()

    {:noreply, %__MODULE__{socket: accept_socket, repo_conn: repo_conn}}
  end

  def handle_cast(
        {:mark_song, current_song},
        state = %__MODULE__{uid: uid, repo_conn: repo_conn}
      ) do
    Repo.mark_song_for_user(repo_conn, current_song, uid)

    {:noreply, state}
  end

  def handle_cast(
        :play_songs,
        state = %__MODULE__{
          source: source,
          queue: [song | rest],
          history: history,
          repo_conn: repo_conn,
          preferences: preferences
        }
      ) do
    File.close(source)

    path = "#{@base_dir}/#{song.path}"
    {start, stop} = FileServer.Mp3Cues.find(path)
    header = Utils.make_header(song)
    {:ok, new_source} = File.open(path, [:read, :binary, :raw])
    new_queue = songs_from_preferences(repo_conn, preferences, rest)

    GenServer.cast(self(), :send_file)

    {:noreply,
     %{
       state
       | source: new_source,
         header: header,
         offset: start,
         stop: stop,
         current_song: song,
         queue: new_queue,
         history: [song | history]
     }}
  end

  def handle_cast(
        :send_file,
        state = %__MODULE__{
          current_song: current_song,
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

    if last >= stop do
      max = stop - offset
      {:ok, bin} = :file.pread(source, offset, max)

      new_buffer = :erlang.list_to_binary([buffer, bin])

      GenServer.cast(self(), {:mark_song, current_song})
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
        # TODO: handle properly
        exit(:error)
    end
  end

  defp songs_from_preferences(repo_conn, preferences, []) do
    Repo.songs_from_preferences(repo_conn, preferences)
  end

  defp songs_from_preferences(_repo_conn, _preferences, queue), do: queue
end
