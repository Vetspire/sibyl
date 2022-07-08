defmodule SibylTest do
  use ExUnit.Case
  doctest Sibyl

  test "greets the world" do
    assert Sibyl.hello() == :world
  end
end
