defmodule ApplicationServer.Configuration do
  @moduledoc "Central place to fetch application configuration values."
  def secure?, do: Application.get_env(:dart_messaging_server, :server)[:secure]
  def port, do: Application.get_env(:dart_messaging_server, :server)[:port]
  def certfile, do: Application.get_env(:dart_messaging_server, :server)[:certfile]
  def keyfile, do: Application.get_env(:dart_messaging_server, :server)[:keyfile]
  def route, do: Application.get_env(:dart_messaging_server, :server)[:route]
end