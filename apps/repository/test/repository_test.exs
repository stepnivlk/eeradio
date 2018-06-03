defmodule RepositoryTest do
  use ExUnit.Case
  doctest Repository

  test "greets the world" do
    assert Repository.hello() == :world
  end
end
