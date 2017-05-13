defmodule Mtproto2json do
  @registry Application.get_env(:mtproto2json, :registry_name)

  def registry, do: @registry

  def new(port) do
    new(port, fn data -> IO.inspect data end)
  end

  def new(port, cb) do
    Mtproto2json.StreamersSupervisor.start_child(port, cb)
  end

  def send(port, data) do
    Mtproto2json.Connector.send(port, data)
  end

  def call(port, data) do
    Mtproto2json.Connector.call(port, data)
  end
end
