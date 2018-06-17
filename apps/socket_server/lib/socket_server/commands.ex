defmodule SocketServer.Commands do
  @moduledoc false

  defstruct [:uid, :genre, :song, :album, :playlist]

  def from_request(request) do
    request
    |> :erlang.binary_to_list()
    |> :string.tokens('\r\n')
    |> Enum.map(fn command -> :string.tokens(command, ' ') end)
    |> from_tokens
  end

  def from_tokens([['GET', raw_preferences, _] | _tail]) do
    raw_preferences
    |> to_string()
    |> String.replace("/", "")
    |> String.replace("?", "")
    |> String.split("&")
    |> build_items(%__MODULE__{})
  end

  def from_tokens(_), do: %__MODULE__{}

  defp build_items([item | rest], result) do
    build_items(rest, item_to_result(item, result))
  end

  defp build_items([], result), do: result

  defp item_to_result("uid=" <> uid, result), do: result |> Map.merge(%{uid: uid})
  defp item_to_result("genre=" <> genre, result), do: result |> Map.merge(%{genre: genre})
  defp item_to_result("song=" <> song, result), do: result |> Map.merge(%{song: song})
  defp item_to_result("album=" <> album, result), do: result |> Map.merge(%{album: album})
end
