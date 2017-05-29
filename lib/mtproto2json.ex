defmodule Mtproto2json do
  @registry Application.get_env(:mtproto2json, :registry_name)

  def registry, do: @registry

  def new(name, handler, session) do
    Mtproto2json.Workers.start_child(name, handler, session)
  end

  def stop(name, reason \\ :shutdown) do
    Mtproto2json.Connector.Sup.stop(name, reason)
  end

  def send(name, data), do: Mtproto2json.Connector.send(name, data)
  def send(name, data, timeout), do: Mtproto2json.Connector.send(name, data, timeout)

  def call(name, data), do: Mtproto2json.Connector.call(name, data)
  def call(name, data, timeout), do: Mtproto2json.Connector.call(name, data, timeout)

  def find_chat(name, id) do
    Mtproto2json.Decoder.find(name, :chats, id)
  end

  def find_user(name, id) do
    Mtproto2json.Decoder.find(name, :users, id)
  end

end
