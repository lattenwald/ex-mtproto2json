defmodule Mtproto2json.Msg do
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
    |> cons(peer: peer, message: text, random_id: :rand.uniform(1000000000))
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
end
