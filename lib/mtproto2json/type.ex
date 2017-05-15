defmodule Mtproto2json.Type.User do
  defstruct [:id, :first_name, :last_name, :username, :phone, {:bot, false}, :access_hash]
end

defmodule Mtproto2json.Type.Channel do
  defstruct [:id, :title, :access_hash]
end

defmodule Mtproto2json.Type.Message do
  defstruct [:id, :from_id, :to_id, :chat_id, :user_id, :sender, :message, :out]
end
