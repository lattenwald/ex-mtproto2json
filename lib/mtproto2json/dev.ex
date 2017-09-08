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
    Mtproto2json.new name, auth(authfile)
    Mtproto2json.add_event_handler name, Mtproto2json.DevHandler
  end

  def decstate(name) do
    Mtproto2json.Decoder.get_state name
  end

  def loginspect(stuff) do
    Logger.warn "#{inspect stuff}"
    stuff
  end

  defp finalizeGetDialogs({users, chats}, name) do
    Mtproto2json.Decoder.merge_dialogs(name, %{users: users, chats: chats})
  end

  def getDialogs(name, o_id \\ 0, o_date \\ 0, o_peer \\ nil, users \\ %{}, chats \\ %{}, messages \\ %{}) do
    o_peer = o_peer || Mtproto2json.Msg.cons("inputPeerEmpty")

    msg = Mtproto2json.Msg.getDialogs(0, o_id, o_date, o_peer)
    resp = Mtproto2json.call(name, msg, 30000)["message"]

    new_users = Map.merge users,
      Mtproto2json.Decoder.Helpers.decode2map(resp["users"] || [])
    new_chats = Map.merge chats,
      Mtproto2json.Decoder.Helpers.decode2map(resp["chats"] || [])
    new_messages = Map.merge messages,
      Mtproto2json.Decoder.Helpers.decode2map(resp["messages"] || [])

    case resp["dialogs"] do
      nil -> {new_users, new_chats} |> finalizeGetDialogs(name)
      []  -> {new_users, new_chats} |> finalizeGetDialogs(name)
      dialogs ->
        dialog = List.last(dialogs)
        new_id = dialog["top_message"]
        new_date = case new_messages[new_id] do
                     nil ->
                       Logger.warn "#{__MODULE__} getDialogs #{inspect name}: no message with id #{new_id}"
                       # TODO: when messages are stored, fetch from storage
                       0 # actually... (. ﾟーﾟ)
                     m -> m.date
                   end
        new_peer =
          case dialog["peer"] do
            %{"_cons" => "peerUser", "user_id" => user_id} ->
              Mtproto2json.Msg.inputPeer(new_users[user_id])
            %{"_cons" => "peerChannel", "channel_id" => chat_id} ->
              Mtproto2json.Msg.inputPeer(new_chats[chat_id])
            %{"_cons" => "peerChat", "chat_id" => chat_id} ->
              Mtproto2json.Msg.inputPeer(new_chats[chat_id])
          end
        if new_date == 0 do
          {new_users, new_chats} |> finalizeGetDialogs(name)
        else
          getDialogs(name, new_id, new_date, new_peer, new_users, new_chats, new_messages)
        end
    end
  end

end

defmodule Mtproto2json.DevHandler do
  require Logger
  behaviour :gen_event

  alias Mtproto2json.Type.Message
  alias Mtproto2json.Type.User
  alias Mtproto2json.Type.Chat
  alias Mtproto2json.Type.Channel
  alias Mtproto2json.Type.Event

  def init(_), do: {:ok, :ok}
  def handle_call(_, state), do: {:ok, state}
  def handle_info(_, state), do: {:ok, state}
  def code_change(_old_vsn, state, _extra), do: {:ok, state}
  def terminate(_reason, _state), do: :ok

  def handle_event(event, state) do
    Logger.debug "#{inspect event}"
    pp event
    {:ok, state}
  end

  # defp pp(msg), do: IO.inspect msg
  defp pp(%Event{name: name, data: data}) do
    time = :io_lib.format '~4..0B/~2..0B/~2..0B ~2..0B:~2..0B:~2..0B', (:calendar.local_time |> Tuple.to_list |> Enum.map(&Tuple.to_list(&1)) |> List.flatten)
    IO.puts "#{time} #{name} #{pp data}"
  end
  defp pp(%Message{
        id: id,
        sender: s,
        recipient: r,
        message: m,
        media: media,
        reply_markup: markup,
        fwd: f
    }
  ) do
    msg = m
    |> String.replace("\n", "\\n")
    |> String.slice(0, 100)
    |> case do
         "" -> inspect media
         other -> other
       end

    "[#{id}] #{pp s} #{if f, do: "[fwd] "}-> #{pp r} : #{msg}#{pp markup}"
  end
  defp pp(%Chat{title: t}) when not(is_nil t), do: "(chat #{t})"
  defp pp(%Channel{title: t}) when not(is_nil t), do: "(channel #{t})"
  defp pp(%User{username: u}) when not(is_nil u), do: "@#{u}"
  defp pp(%User{first_name: f}) when not(is_nil f), do: f
  defp pp(nil), do: ""
  defp pp({:inline_markup, buttons}) do
    str =
      buttons
      |> Enum.map(&pp(&1))
      |> Enum.join(", ")
    " inl:[#{str}]"
  end
  defp pp({:keyboard_markup, buttons}) do
    str =
      buttons
      |> Enum.map(&pp(&1))
      |> Enum.join(", ")
    " kbd:[#{str}]"
  end
  defp pp(%{game_text: text}), do: "game(#{text})"
  defp pp(%{buy_text: text}), do: "buy(#{text})"
  defp pp(%{text: text}), do: text
  defp pp(other), do: IO.inspect other
end
