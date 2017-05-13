defmodule Mtproto2json do
  @registry Application.get_env(:mtproto2json, :registry_name)

  def registry, do: @registry
end
