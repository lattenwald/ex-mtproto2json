defmodule Mtproto2json do
  @registry Application.get_env(:mtproto2json, :registry_name)

  def registry, do: @registry

  # def start_link(module) do
  #   cb = &module.handle/1
  # end

  def new(name, fun \\ fn data -> IO.inspect data end) do
    Mtproto2json.Sup.start_child(fun, name)
  end

  def send(name, data) do
    Mtproto2json.Connector.send(name, data)
  end

  def call(name, data) do
    Mtproto2json.Connector.call(name, data)
  end
end
