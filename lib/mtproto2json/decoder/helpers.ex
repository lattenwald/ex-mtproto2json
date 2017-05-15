defmodule Mtproto2json.Decoder.Helpers do
  require Logger
  alias Mtproto2json.Type.User
  alias Mtproto2json.Type.Channel
  alias Mtproto2json.Type.Message

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

  def decode(msg=%{"_cons" => "message"}) do
    out = decode(msg["out"]) || false

    map = [:id, :from_id, :to_id, :user_id, :message]
    |> Enum.map(&({&1, msg[Atom.to_string &1]}))
    |> Enum.into(%{out: out})

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
    out = decode(msg["out"]) || false |> IO.inspect

    map = [:id, :from_id, :user_id, :message]
    |> Enum.map(&({&1, msg[Atom.to_string &1]}))
    |> Enum.into(%{out: out})
    |> IO.inspect

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

  def t do # TODO: removeme
    %{"id" => 0,
      "message" => %{
        "_cons" => "updates",
        "chats" => [
          %{"_cons" => "channel", "date" => 1493567749,
            "democracy" => %{"_cons" => "true"}, "id" => 1091311299,
            "megagroup" => %{"_cons" => "true"}, "min" => %{"_cons" => "true"},
            "photo" => %{
              "_cons" => "chatPhoto",
              "photo_big" => %{
                "_cons" => "fileLocation", "dc_id" => 2,
                "local_id" => 202049, "secret" => -8122666735636340086,
                "volume_id" => 230111254},
              "photo_small" => %{
                "_cons" => "fileLocation", "dc_id" => 2,
                "local_id" => 202047, "secret" => -5367001117789253139,
                "volume_id" => 230111254}},
            "title" => "Сумрачный Замок (Chat Wars)", "version" => 0}],
        "date" => 1494776533, "seq" => 0,
        "updates" => [
          %{"_cons" => "updateNewChannelMessage",
            "message" => %{
              "_cons" => "message", "date" => 1494776533,
              "entities" => [
                %{"_cons" => "messageEntityMention", "length" => 12,
                  "offset" => 24}],
              "from_id" => 319324463, "id" => 51259,
              "message" => "А, ты хочешь в темницу, @AlBagdadi11?",
              "to_id" => %{"_cons" => "peerChannel", "channel_id" => 1091311299}},
            "pts" => 56357, "pts_count" => 1}],
        "users" => [
          %{"_cons" => "user", "bot" => %{"_cons" => "true"},
            "bot_chat_history" => %{"_cons" => "true"}, "bot_info_version" => 5,
            "first_name" => "Опричник", "id" => 319324463,
            "min" => %{"_cons" => "true"},
            "photo" => %{
              "_cons" => "userProfilePhoto",
              "photo_big" => %{
                "_cons" => "fileLocation", "dc_id" => 2,
                "local_id" => 448136, "secret" => -7076650125228086396,
                "volume_id" => 223023449},
              "photo_id" => 1371488125854001067,
              "photo_small" => %{
                "_cons" => "fileLocation", "dc_id" => 2,
                "local_id" => 448134, "secret" => 8661016411945357410,
                "volume_id" => 223023449}},
            "username" => "ChatWarsPoliceBot"}]}}
  end
end
