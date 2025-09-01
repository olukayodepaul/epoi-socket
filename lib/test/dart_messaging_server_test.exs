defmodule DartMessagingServerTest do
  use ExUnit.Case
  doctest DartMessagingServer

  test "greets the world" do
    assert DartMessagingServer.hello() == :world
  end
end
