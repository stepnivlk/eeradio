defmodule FileServerTest do
  use ExUnit.Case
  doctest FileServer

  test "greets the world" do
    assert FileServer.hello() == :world
  end
end
