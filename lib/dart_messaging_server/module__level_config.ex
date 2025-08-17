defmodule ApplicationServer.Configuration do

  @app :dart_messaging_server

  def secure?, do: get(:server)[:secure]
  def port, do: get(:server)[:port]
  def certfile, do: get(:server)[:certfile]
  def keyfile, do: get(:server)[:keyfile]
  def route, do: get(:server)[:route]
  def sign_alg, do: get(:server)[:sign_alg]
  def pb_key_file_path, do: get(:server)[:pb_key_file_path]
  def ping_interval, do: get(:server)[:ping_interval]
  def max_missed_pongs, do: get(:server)[:max_missed_pongs]
  def idle_timeout, do: get(:server)[:idle_timeout]
  def selected_db, do: get(:server)[:selected_db]
  
  defp get(key), do: Application.get_env(@app, key, [])
end