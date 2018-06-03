defmodule FileServer.Mp3Cues do
  @moduledoc """
  Find start and stop positions of data in a mp3 file.
  """

  @idv1_size 128

  @type positions :: {integer, integer} | :not_found

  @spec find(String.t()) :: positions
  def find(file_path) do
    with {:ok, [idv1tag, idv2tag]} <- :id3_tag_reader.read_tag(file_path),
         {:ok, start} <- start_from_idv2(idv2tag),
         {:ok, file_size} <- file_size(file_path),
         {:ok, stop} <- stop_from_idv1(idv1tag, file_size) do
      {start, stop}
    else
      error -> error
    end
  end

  defp start_from_idv2({:idv2tag, :not_found}), do: :not_found

  defp start_from_idv2(
         {:idv2tag, [{:header, [_version, _flags, {:size, size}]}, _ext_header, _tags]}
       ) do
    {:ok, size + 10}
  end

  defp stop_from_idv1({:idv1tag, :not_found}, file_size), do: {:ok, file_size}

  defp stop_from_idv1({:idv1tag, _idv1tag}, file_size), do: {:ok, file_size - @idv1_size}

  defp file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: file_size}} -> {:ok, file_size}
      {:error, _reason} -> :not_found
    end
  end
end
