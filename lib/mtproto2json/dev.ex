defmodule Mtproto2json.Dev do
  def init() do
    Registry.start_link(:unique, Mtproto2json.registry())
  end

  def start_link(port) do
    cb = fn data -> IO.puts "[in] #{inspect data}" end
    Mtproto2json.Sup.start_link(port, cb)
  end

  def send(port, data) do
    Mtproto2json.Connector.send(port, data)
  end

  def auth do
    Application.get_env(:mtproto2json, :auth_file)
    |> File.read!
  end
end
