defmodule SocketServer.Commands do
  @moduledoc false

  defstruct [:uid, :port]

  def from_request(request) do
    request
    |> :erlang.binary_to_list()
    |> :string.tokens('\r\n')
    |> Enum.map(fn command -> :string.tokens(command, ' ') end)
  end

  def to_struct(commands) do
    uid = uid(commands)
    port = port(commands)

    %__MODULE__{uid: uid, port: port}
  end

  def uid([['GET', uid, _] | _tail]) do
    uid
    |> to_string()
    |> do_uid()
  end

  def uid(_), do: :error

  def port([_, ['Host:', host] | _tail]) do
    host
    |> to_string()
    |> String.split(":")
    |> List.last()
  end

  def port(_), do: :error

  defp do_uid("/" <> uid), do: uid

  defp do_uid(_), do: :anon
end
