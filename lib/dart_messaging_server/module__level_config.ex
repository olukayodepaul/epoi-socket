defmodule ApplicationServer.Configuration do

  @app :dart_messaging_server

  #server
  def secure?, do: get(:server)[:secure]
  def port, do: get(:server)[:port]
  def certfile, do: get(:server)[:certfile]
  def keyfile, do: get(:server)[:keyfile]
  def route, do: get(:server)[:route]
  def sign_alg, do: get(:server)[:sign_alg]
  def pb_key_file_path, do: get(:server)[:pb_key_file_path]
  def idle_timeout, do: get(:server)[:idle_timeout]
  def selected_db, do: get(:server)[:selected_db]
  def awareness_topic, do: get(:server)[:awareness_topic]


  #network
  def max_pong_counter, do: get(:network_ping_pong)[:max_pong_counter]
  def max_allowed_delay, do: get(:network_ping_pong)[:max_allowed_delay]
  def default_ping_interval, do: get(:network_ping_pong)[:default_ping_interval]
  def initial_adaptive_max_missed, do: get(:network_ping_pong)[:initial_adaptive_max_missed]

  #processor_state
  def client_stale_threshold_seconds, do: get(:processor_state)[:stale_threshold_seconds]
  def client_force_change_seconds, do: get(:processor_state)[:force_change_seconds]

  #monitor_state
  def server_stale_threshold_seconds, do: get(:monitor_state)[:stale_threshold_seconds]
  def server_force_change_seconds, do: get(:monitor_state)[:force_change_seconds]
  
  
  defp get(key), do: Application.get_env(@app, key, [])
end