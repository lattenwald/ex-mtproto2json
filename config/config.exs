use Mix.Config

# config :porcelain,
#   driver: Porcelain.Driver.Basic

config :mtproto2json,
  registry_name: :mtproto2json,
  mtproto2json_dir: "/Users/aleksandrkusev/projects/mtproto2json",
  send_timeout: 5000,
  conn_timeout: 5000,
  auth_file: "/Users/aleksandrkusev/projects/elixir/ex-mtproto2json/auth.json"

# this file includes secret.exs if present
try do
  import_config "secret.exs"
catch
  _, _ -> :missing
end
