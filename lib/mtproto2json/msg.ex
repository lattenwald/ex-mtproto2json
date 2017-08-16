defmodule Mtproto2json.Msg do
  @random_upper 1000000000

  alias Mtproto2json.Type.User
  alias Mtproto2json.Type.Chat
  alias Mtproto2json.Type.Channel

  def cons(constructor, params \\ []) do
    Enum.into(params, %{:_cons => constructor})
  end

  def msg(body), do: %{message: body}

  def ping(id \\ 100), do: cons("ping", ping_id: id) |> msg

  def getState, do: "updates.getState" |> cons |> msg

  # def getDialogs(limit \\ 0, offset_id \\ 0, offset_peer \\ nil) do
  def getDialogs(limit \\ 0, offset_id \\ 0, offset_date \\ 0, offset_peer \\ nil) do
    offset_peer = offset_peer || cons("inputPeerEmpty")
    cons(
      "messages.getDialogs",
      offset_date: offset_date, offset_id: offset_id, offset_peer: offset_peer, limit: limit
    ) |> msg
  end

  def sendMessage(peer, text) do
    "messages.sendMessage"
    |> cons(peer: peer, message: text, random_id: :rand.uniform(@random_upper))
    |> msg
  end

  def updateStatus(offline \\ false) do
    "account.updateStatus"
    |> cons(offline: bool(offline))
    |> msg
  end

  def bool(val) do
    case val do
      true  -> "boolTrue"
      false -> "boolFalse"
    end
    |> cons
  end

  def inlineClick(peer, msg_id, data) do
    "messages.getBotCallbackAnswer"
    |> cons(msg_id: msg_id, data: data, peer: peer)
    |> msg
  end

  def forwardMessages(to, from, msg_ids) do
    to_peer = inputPeer(to)
    from_peer = inputPeer(from)
    random_ids = msg_ids |> Enum.map(fn _ -> :rand.uniform(@random_upper) end)

    "messages.forwardMessages"
    |> cons(from_peer: from_peer, to_peer: to_peer,
    id: msg_ids, random_id: random_ids)
    |> msg
  end

  def inputPeer(nil), do: nil

  def inputPeer(%User{access_hash: access_hash, id: id}) do
    "inputPeerUser" |> cons(user_id: id, access_hash: access_hash)
  end

  def inputPeer(%Chat{id: id}) do
    "inputPeerChat" |> cons(chat_id: id)
  end

  def inputPeer(%Channel{id: id, access_hash: access_hash}) do
    "inputPeerChannel" |> cons(channel_id: id, access_hash: access_hash)
  end

  def forwardMessage(to, from, msg_id) do
    to_peer = inputPeer(to)
    from_peer = inputPeer(from)
    random_id = :rand.uniform(@random_upper)

    "messages.forwardMessage"
    |> cons(from_peer: from_peer, to_peer: to_peer,
    id: msg_id, random_id: random_id)
    |> msg
  end
end
