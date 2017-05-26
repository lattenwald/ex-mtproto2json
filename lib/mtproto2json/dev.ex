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

  def start(name, authfile) do
    Mtproto2json.new name, Mtproto2json.DevHandler, auth(authfile)
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

defmodule Mtproto2json.DevHandler do
  require Logger
  use GenEvent

  alias Mtproto2json.Type.Message
  alias Mtproto2json.Type.User
  alias Mtproto2json.Type.Chat

  def handle_event(event, state) do
    Logger.debug "#{inspect event}"
    pp event
    {:ok, state}
  end

  # defp pp(msg), do: IO.inspect msg
  defp pp(%Message{
        id: id,
        sender: s,
        recipient: r,
        replyto: rto,
        message: m,
        media: media,
        reply_markup: markup
    }
  ) do
    msg = m
    |> String.replace("\n", "\\n")
    |> String.slice(0, 100)
    |> case do
         "" -> inspect media
         other -> other
       end

    IO.puts "#{DateTime.to_string(DateTime.utc_now)} [#{id}] #{pp s} -> #{pp r} : #{pp rto} : #{inspect markup} : #{msg}"
  end
  defp pp(other, name), do: "#{name} #{inspect other}"
  defp pp(%Chat{title: t}) when not(is_nil t), do: "(#{t})"
  defp pp(%User{username: u}) when not(is_nil u), do: "@#{u}"
  defp pp(%User{first_name: f}) when not(is_nil f), do: f
  defp pp(other), do: inspect other
end
