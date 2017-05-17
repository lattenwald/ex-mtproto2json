defmodule Mtproto2json do
  @registry Application.get_env(:mtproto2json, :registry_name)

  def registry, do: @registry

  def new(name, session, fun \\ fn data -> IO.inspect data end) do
    Mtproto2json.Sup.start_child(session, fun, name)
  end

  def stop(name, reason \\ :shutdown) do
    Mtproto2json.Connector.Sup.stop(name, reason)
  end

  def send(name, data) do
    Mtproto2json.Connector.send(name, data)
  end

  def call(name, data) do
    Mtproto2json.Connector.call(name, data)
  end

  def find_channel(name, id) do
    Mtproto2json.Decoder.find(name, :channels, id)
  end

  def find_user(name, id) do
    Mtproto2json.Decoder.find(name, :users, id)
  end
end
