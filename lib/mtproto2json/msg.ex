defmodule Mtproto2json.Msg do
  def cons(constructor, params \\ []) do
    Enum.into(params, %{:_cons => constructor})
  end

  def msg(body), do: %{message: body}

  def ping(id \\ 100), do: cons("ping", ping_id: id) |> msg

  def getState, do: "updates.getState" |> cons |> msg

  def getDialogs do
    cons(
      "messages.getDialogs",
      offset_date: 0, offset_id: 0, offset_peer: cons("inputPeerEmpty"), limit: 0
    ) |> msg
  end
end
