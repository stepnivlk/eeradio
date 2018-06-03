defmodule SocketServerTest do
  use ExUnit.Case
  doctest SocketServer

  test "greets the world" do
    assert SocketServer.hello() == :world
  end
end
