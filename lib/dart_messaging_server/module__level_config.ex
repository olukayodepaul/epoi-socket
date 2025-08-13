defmodule ApplicationServer.Configuration do
  def secure?, do: Application.get_env(:dart_messaging_server, :server)[:secure]
  def port, do: Application.get_env(:dart_messaging_server, :server)[:port]
  def certfile, do: Application.get_env(:dart_messaging_server, :server)[:certfile]
  def keyfile, do: Application.get_env(:dart_messaging_server, :server)[:keyfile]
  def route, do: Application.get_env(:dart_messaging_server, :server)[:route]
  def sign_alg, do: Application.get_env(:dart_messaging_server, :server)[:sign_alg]
  def pb_key_file_path, do: Application.get_env(:dart_messaging_server, :server)[:pb_key_file_path]
  def ping_interval, do: Application.get_env(:dart_messaging_server, :server)[:ping_interval]
  def max_missed_pongs, do: Application.get_env(:dart_messaging_server, :server)[:max_missed_pongs]
end