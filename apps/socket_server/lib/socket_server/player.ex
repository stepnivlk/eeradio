defmodule SocketServer.Player do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @chunksize 24_576
      @temp_dir "../data/8b8e0cf1774dd1ea6c1d181d4d894259"

      defp play_songs(socket, buffer) do
        song = songs() |> Enum.random()
        path = "#{@temp_dir}/#{song}"

        {start, stop} = FileServer.Mp3Cues.find(path)

        header = make_header(song)

        IO.puts("Playing song: #{inspect(song)}")

        {:ok, source} = File.open(path, [:read, :binary, :raw])

        new_buffer = send_file(source, header, start, stop, socket, buffer)

        File.close(source)

        play_songs(socket, new_buffer)

        :ok
      end

      defp send_file(source, header, offset, stop, socket, buffer) do
        need = @chunksize - byte_size(buffer)
        last = offset + need

        IO.inspect("send_file #{inspect(offset)} #{inspect(need)}")

        if last >= stop do
          max = stop - offset
          {:ok, bin} = :file.pread(source, offset, max)
          :erlang.list_to_binary([buffer, bin])
        else
          {ok, bin} = :file.pread(source, offset, need)
          write_data(socket, buffer, bin, header)
          send_file(source, header, offset + need, stop, socket, <<>>)
        end
      end

      def write_data(socket, buffer, bin, header) do
        case byte_size(buffer) + byte_size(bin) do
          @chunksize ->
            case :gen_tcp.send(socket, [buffer, bin, header]) do
              :ok -> true
              {:error, :closed} -> exit(:player_closed)
            end

          _other ->
            IO.inspect("Block length error: #{inspect(buffer)} | #{inspect(bin)}")
        end
      end

      defp songs do
        {:ok, files} = File.ls(@temp_dir)
        Enum.filter(files, fn file -> String.ends_with?(file, "mp3") end)
      end

      defp make_header(name) do
        bin = "StreamTitle='#{name}';StreamUrl='http://localhost:3121/stepnivlk';"

        n_blocks = div(byte_size(bin) - 1, 16) + 1
        n_pad = n_blocks * 16 - byte_size(bin)
        extra = :lists.duplicate(n_pad, 0)

        :erlang.list_to_binary([n_blocks, bin, extra])
      end
    end
  end
end
