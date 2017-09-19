use Mix.Config

config :logger,
  level: :info

config :mtproto2json,
  registry_name: :mtproto2json,
  mtproto2json_dir: "/Users/aleksandrkusev/projects/mtproto2json",
  send_timeout: 5000,
  conn_timeout: 5000,
  watchdog_period: 60000,
  watchdog_timeout: 30000

# this file includes secret.exs if present
try do
  import_config "secret.exs"
catch
  _, _ -> :missing
end
