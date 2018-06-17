defmodule SocketServer.Buffer do
  @moduledoc false

  use GenServer

  alias SocketServer.{Commands, StreamSupervisor, Utils}
  alias Repository.Repo
  alias Bolt.Sips

  @chunk_size 24_576
  @buffer_size @chunk_size * 100
  @queue_limit_length 0

  defstruct commands: %Commands{},
            queue: [],
            buffer: <<>>,
            repo_conn: nil,
            current_song: nil,
            stream_id: nil,
            parent_pid: nil

  ## ==========================================================================
  ## CLIENT
  ## ==========================================================================

  def start_link(commands), do: GenServer.start_link(__MODULE__, commands)

  def request_chunk(pid) do
    GenServer.call(pid, :request_chunk)
  end

  def reset_for_commands(pid, commands) do
    GenServer.cast(pid, :reset_for_commands)
  end

  ## ==========================================================================
  ## SERVER
  ## ==========================================================================

  def init(commands) do
    repo_conn = Sips.conn()
    GenServer.cast(self(), :init_buffer)
    {:ok, %__MODULE__{commands: commands, repo_conn: repo_conn}}
  end

  ## ==========================================================================
  ## Local handlers
  ## ==========================================================================

  def handle_call(
        :request_chunk,
        _from,
        state = %{
          stream_id: id,
          current_song: current_song,
          buffer: <<chunk::binary-size(@chunk_size), rest::binary>>
        }
      ) do
    if byte_size(rest) < @buffer_size do
      :ibrowse.stream_next(id)
    end

    {:reply, {:ok, chunk, current_song}, %{state | buffer: rest}}
  end

  def handle_call(:request_chunk, _from, state = %{stream_id: id}) do
    :ibrowse.stream_next(id)
    {:reply, {:error, :nodata}, state}
  end

  def handle_cast(:init_buffer, state = %{repo_conn: repo_conn, commands: commands}) do
    [current_song | queue] = Repo.songs_from_commands(repo_conn, commands)

    stream_id = open_stream(current_song)

    {:noreply, %{state | queue: queue, current_song: current_song, stream_id: stream_id}}
  end

  # TODO
  def handle_cast(:reset_for_commands, state) do
    {:noreply, state}
  end

  ## ==========================================================================
  ## Pull Chunks from server callback
  ## ==========================================================================

  def handle_info(
        {:ibrowse_async_headers, id, '200', headers},
        state = %{stream_id: stream_id}
      ) do
    {:noreply, state}
  end

  @doc ~S"""
  First data frame after the headers.
  Found ID3v2. 73, 68, 51 are codepoints of I, D and 3 characters.
  """
  def handle_info(
        {:ibrowse_async_response, id, raw_bin = [73, 68, 51 | _]},
        state = %{buffer: buffer}
      ) do
    bin = :erlang.list_to_binary(raw_bin)

    <<header::bytes-size(10), _::binary>> = bin

    id3_size = id3_size_from_header(header)

    <<_id3::bytes-size(id3_size), ext_header::bytes-size(10), mp3_data::binary>> = bin

    :ibrowse.stream_next(id)

    {:noreply, %{state | buffer: buffer <> mp3_data}}
  end

  def handle_info({:ibrowse_async_response, id, raw_bin}, state = %{buffer: buffer}) do
    bin = :erlang.list_to_binary(raw_bin)

    buffer_size = byte_size(buffer)

    if buffer_size <= @buffer_size do
      :ibrowse.stream_next(id)
    end

    {:noreply, %{state | buffer: buffer <> bin}}
  end

  def handle_info({:ibrowse_async_response_end, id}, state = %{queue: [next_song | rest], buffer: buffer}) do
    :ibrowse.stream_close(id)

    open_stream(next_song)

    {:noreply, state}
  end

  ## ==========================================================================
  ## Start ibrowse for given url
  ## ==========================================================================

  defp open_stream(%{url: url}) do
    {:ibrowse_req_id, stream_id} =
      :ibrowse.send_req(
        String.to_charlist(url),
        [],
        :get,
        [],
        [{:stream_to, {self(), :once}}, {:stream_chunk_size, 4000}],
        :infinity
      )

    stream_id
  end

  ## ==========================================================================
  ## Pull Chunks from server utils
  ## ==========================================================================

  @doc ~S"""
  Extract size value from ID3v2 header
  """
  defp id3_size_from_header(
         <<"ID3", version::binary-size(2), flags::integer-8, raw_size::binary-size(4), _::binary>>
       ) do
    <<0::integer-1, s1::integer-7, 0::integer-1, s2::integer-7, 0::integer-1, s3::integer-7,
      0::integer-1, s4::integer-7>> = raw_size

    <<size::integer-28>> = <<s1::integer-7, s2::integer-7, s3::integer-7, s4::integer-7>>
    size
  end

  defp id3_size_from_header(_), do: :error

  # TODO
  # MP3 header pattern
  defp match_header(<<0b11111111111::11, b::2, c::2, d::1, e::4, f::2, g::2, rest::binary>>) do
    :ok
  end
end
