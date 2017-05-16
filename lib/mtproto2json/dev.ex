defmodule Mtproto2json.Dev do
  require Logger

  @authfile Application.get_env(:mtproto2json, :auth_file)

  def auth(file \\ @authfile) do
    Logger.info "auth from file #{file}"
    file
    |> File.read!
    |> Poison.decode!
    |> Map.delete("id")
  end

  # defp pp(msg), do: IO.inspect msg
  defp pp(%{id: id, sender: s, recipient: r, message: m, media: media, reply_markup: markup}, name) do
    msg = m
    |> String.replace("\n", "\\n")
    |> String.slice(0, 100)
    |> case do
         "" -> inspect media
         other -> other
       end

    IO.puts "#{DateTime.to_string(DateTime.utc_now)} #{name} [#{id}] #{pp s} -> #{pp r} : #{inspect markup} : #{msg}"
  end
  defp pp(other, name), do: "#{name} #{inspect other}"
  defp pp(%{title: t}) when not(is_nil t), do: "(#{t})"
  defp pp(%{username: u}) when not(is_nil u), do: "@#{u}"
  defp pp(%{first_name: f}) when not(is_nil f), do: f
  defp pp(other), do: inspect other

  def start(name, authfile) do
    Mtproto2json.Decoder.start_link(name, fn msg -> pp(msg, "#{name} ") end)
    cb = fn data ->
      Mtproto2json.Decoder.incoming(name, data)
    end

    Mtproto2json.new name, auth(authfile), cb
    # Mtproto2json.call name, auth(authfile)
    # dialogs = Mtproto2json.call name, Mtproto2json.Msg.getDialogs
    # Mtproto2json.Decoder.incoming name, dialogs
    # Mtproto2json.send name, Mtproto2json.Msg.getState
  end

  def tochat(what, chat_id \\ 241270154, name \\ 1) do
    Mtproto2json.call name, Mtproto2json.Msg.chatMessage(chat_id, what)
  end

  def touser(what, user \\ nil, name \\ 1) do
    user = user || decstate(name).users[122247178]
    Mtproto2json.call name, Mtproto2json.Msg.userMessage(user, what)
  end

  def decstate(name) do
    Mtproto2json.Decoder.get_state name
  end
end
