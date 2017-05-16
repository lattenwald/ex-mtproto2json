defmodule Mtproto2json.Decoder.Helpers do
  require Logger

  alias Mtproto2json.Type.User
  alias Mtproto2json.Type.Channel
  alias Mtproto2json.Type.Message

  require User
  require Channel
  require Message

  def decode(%{"_cons" => "document", "attributes" => attrs}) do
    attrList = attrs |> Enum.map(&(&1["_cons"]))
    cond do
      "documentAttributeSticker" in attrList -> :sticker
      "documentAttributeAnimated" in attrList -> :animation
      "documentAttributeVideo" in attrList -> :video
      "documentAttributeAudio" in attrList -> :audio
      ["documentAttributeFilename"] == attrList -> :file
      true -> inspect attrList
    end
  end

  def decode(%{"_cons" => "messageMediaDocument", "caption" => _caption, "document" => doc}) do
    decode(doc)
  end

  def decode(%{"_cons" => "messageMediaPhoto", "caption" => _caption}) do
    :photo
  end

  def decode(user=%{"_cons" => "user"}) do
    bot = decode(user["bot"]) || false

    map = [:id, :first_name, :last_name, :username, :phone, :access_hash]
    |> Enum.map(&({&1, user[Atom.to_string &1]}))
    |> Enum.into(%{bot: bot})

    struct(User, map)
  end

  def decode(chan=%{"_cons" => "channel"}) do
    map = [:id, :title, :access_hash]
    |> Enum.map(&({&1, chan[Atom.to_string &1]}))
    |> Enum.into(%{})

    struct(Channel, map)
  end

  def decode(chan=%{"_cons" => "chat"}) do
    map = [:id, :title, :access_hash]
    |> Enum.map(&({&1, chan[Atom.to_string &1]}))
    |> Enum.into(%{})

    struct(Channel, map)
  end

  def decode(%{"_cons" => "keyboardButtonCallback", "text" => text, "data" => data}) do
    %{text: text, data: data}
  end

  def decode(%{"_cons" => "keyboardButtonRow", "buttons" => buttons}) do
    buttons |> Enum.map(&decode(&1))
  end

  def decode(%{"_cons" => "replyInlineMarkup", "rows" => rows}) do
    buttons = rows |> Enum.flat_map(&decode(&1))
    {:inlineMarkup, buttons}
  end

  def decode(msg=%{"_cons" => "message"}) do
    out = decode(msg["out"]) || false
    media = decode(msg["media"])
    reply_markup = decode(msg["reply_markup"])

    map = [:id, :from_id, :to_id, :user_id, :message]
    |> Enum.map(&({&1, msg[Atom.to_string &1]}))
    |> Enum.into(%{out: out, media: media, reply_markup: reply_markup})

    if map.message == "" and is_nil(media) do
      Logger.warn "empty message: #{inspect msg}"
    end

    struct(Message, map)
  end

  def decode(
    %{
      "_cons" => cons,
      "chats" => channels,
      "users" => users,
      "updates" => updates,
    }
  ) when cons in ["updates", "updatesCombined"] do
    decoded_updates = updates
    |> Stream.map(&decode(&1))
    |> Enum.filter(&not(is_nil(&1)))

    %{
      users:    decode2map(users),
      channels: decode2map(channels),
      updates:  decoded_updates
    }
  end

  def decode(msg=%{"_cons" => "updateShortMessage"}) do
    out = decode(msg["out"]) || false

    map = [:id, :from_id, :user_id, :message]
    |> Enum.map(&({&1, msg[Atom.to_string &1]}))
    |> Enum.into(%{out: out})

    msg = struct(Message, map)

    %{updates: [msg]}
  end

  def decode(msg=%{"_cons" => "updateShortChatMessage"}) do
    out = decode(msg["out"]) || false

    map = [:id, :from_id, :user_id, :chat_id, :message]
    |> Enum.map(&({&1, msg[Atom.to_string &1]}))
    |> Enum.into(%{out: out})

    msg = struct(Message, map)

    %{updates: [msg]}
  end

  def decode(
    %{
      "_cons" => "messages.dialogs",
      "chats" => channels,
      "users" => users,
      # "updates" => updates,
      "dialogs" => dialogs,
    }) do
    # Logger.warn inspect dialogs

    %{
      users:    decode2map(users),
      channels: decode2map(channels),
      # dialogs:  decode2map(dialogs),
    }
  end

  def decode(%{"_cons" => "updateShort", "update" => upd}) do
    decode(upd)
  end

  def decode(%{"_cons" => "true"}), do: true
  def decode(%{"_cons" => "false"}), do: false
  def decode(%{"_cons" => "boolFalse"}), do: false
  def decode(%{"_cons" => "boolTrue"}), do: true

  def decode(%{"message" => msg}), do: decode(msg)

  def decode(nil), do: nil
  def decode(:ignore), do: nil

  def decode(%{"_cons" => "updateUserStatus"}), do: nil

  def decode(%{"_cons" => cons}) do
    Logger.debug "not decoding #{cons}"
    nil
  end

  def decode(map=%{}) do
    Logger.debug "not decoding unknown map structure: #{inspect map}"
    nil
  end

  def decode(other) do
    Logger.debug "not decoding unknown data: #{inspect other}"
    nil
  end

  def decode2map(data) do
    data
    |> Stream.map(&decode(&1))
    |> Stream.filter(&not(is_nil(&1)))
    |> Stream.map(&({&1.id, &1}))
    |> Enum.into(%{})
  end

end
