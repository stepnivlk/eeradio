defmodule SocketServer.Buffer.LocalBuffer do
  @moduledoc false

  use GenServer

  alias SocketServer.Commands

  @chunksize 24_576

  defstruct commands: %Commands{}, buffer: <<>>, offset: nil, stop: nil

  def start_link(commands), do: GenServer.start_link(__MODULE__, commands)

  def init(commands) do
    {:ok, %__MODULE__{commands: commands}}
  end

  def request_chunk(pid) do
    GenServer.call(pid, :request_chunk)
  end

  def handle_cast(
        :send_file,
        state = %{
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

      GenServer.cast(self(), :play_songs)

      {:noreply, %{state | buffer: new_buffer}}
    else
      {:ok, bin} = :file.pread(source, offset, need)
      # write_data(socket, buffer, bin, header)

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
end
