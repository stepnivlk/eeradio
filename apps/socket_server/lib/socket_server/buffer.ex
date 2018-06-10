defmodule SocketServer.Buffer do
  @moduledoc false

  use GenServer

  alias SocketServer.Commands
  alias Repository.Repo
  alias Bolt.Sips

  defstruct commands: %Commands{},
            queue: [],
            buffer: <<>>,
            repo_conn: nil,
            current: nil,
            stream_id: nil

  def start_link(commands), do: GenServer.start_link(__MODULE__, commands)

  def init(commands) do
    repo_conn = Sips.conn()
    {:ok, %__MODULE__{commands: commands, repo_conn: repo_conn}}
  end

  def init_buffer(pid) do
    GenServer.cast(pid, :init_buffer)
  end

  def handle_cast(:init_buffer, state = %__MODULE__{repo_conn: repo_conn}) do
    preferences = %{genre: "Hardtekno", user_uid: "stepnivlk"}
    [current | queue] = Repo.songs_from_preferences(repo_conn, preferences)
    stream_id = open_socket(current)

    {:noreply, %{state | queue: queue, current: current, stream_id: stream_id}}
  end

  def handle_info(
        {:ibrowse_async_headers, id, '200', headers},
        state = %__MODULE__{stream_id: stream_id}
      ) do
    IO.inspect(headers)
    {:noreply, state}
  end

  # First data frame after the headers.
  # Found ID3v2. 73, 68, 51 are codepoints of I, D and 3 characters.
  def handle_info({:ibrowse_async_response, id, raw_bin = [73, 68, 51 | _]}, state) do
    bin = :erlang.list_to_binary(raw_bin)

    <<header::bytes-size(10), _::binary>> = bin

    id3_size = id3_size_from_header(header)

    <<_id3::bytes-size(id3_size), mp3_data::binary>> = bin
    IO.inspect(mp3_data)

    {:noreply, state}
  end

  def handle_info({:ibrowse_async_response, id, frame}, state) do
    IO.inspect(frame)
    {:noreply, state}
  end

  defp open_socket(%{url: url}) do
    {:ibrowse_req_id, stream_id} =
      :ibrowse.send_req(
        String.to_charlist(url),
        [],
        :get,
        [],
        [{:stream_to, {self(), :once}}],
        :infinity
      )

    stream_id
  end

  # Extract size value from ID3v2 header
  defp id3_size_from_header(
         <<"ID3", version::binary-size(2), flags::integer-8, raw_size::binary-size(4), _::binary>>
       ) do
    <<0::integer-1, s1::integer-7, 0::integer-1, s2::integer-7, 0::integer-1, s3::integer-7,
      0::integer-1, s4::integer-7>> = raw_size

    <<size::integer-28>> = <<s1::integer-7, s2::integer-7, s3::integer-7, s4::integer-7>>
    size
  end

  defp id3_size_from_header(_), do: :error

  # MP3 header pattern
  defp match_header(<<0b11111111111::11, b::2, c::2, d::1, e::4, f::2, g::2, rest::binary>>) do
    :ok
  end
end
