defmodule Mtproto2json.Msg do
  @random_upper 1000000000

  alias Mtproto2json.Type.User
  alias Mtproto2json.Type.Channel

  def cons(constructor, params \\ []) do
    Enum.into(params, %{:_cons => constructor})
  end

  def msg(body), do: %{message: body}

  def ping(id \\ 100), do: cons("ping", ping_id: id) |> msg

  def getState, do: "updates.getState" |> cons |> msg

  def getDialogs(limit \\ 0, offset_id \\ 0) do
    cons(
      "messages.getDialogs",
      offset_date: 0, offset_id: 0, offset_peer: cons("inputPeerEmpty"), limit: 0
    ) |> msg
  end

  def chatMessage(chat_id, text) do
    peer = "inputPeerChat" |> cons(chat_id: chat_id)
    sendMessage(peer, text)
  end

  def userMessage(%{id: user_id, access_hash: access_hash}, text) do
    peer = "inputPeerUser" |> cons(user_id: user_id, access_hash: access_hash)
    sendMessage(peer, text)
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

  def inputPeer(%User{access_hash: access_hash, id: id}) do
    %{"_cons" => "inputPeerUser", "user_id" => id, "access_hash" => access_hash}
  end

  def inputPeer(%Channel{access_hash: access_hash, id: id}) do
    %{"_cons" => "inputPeerChannel", "user_id" => id, "access_hash" => access_hash}
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
