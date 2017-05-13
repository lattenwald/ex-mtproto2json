defmodule Mtproto2json.Dev do
  def auth do
    Application.get_env(:mtproto2json, :auth_file)
    |> File.read!
  end
end
