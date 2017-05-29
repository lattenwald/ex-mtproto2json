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
  alias Mtproto2json.Type.Channel
  alias Mtproto2json.Type.Event

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

    "[#{id}] #{pp s} -> #{pp r} : #{msg}#{pp markup}"
  end
  defp pp(other, name), do: "#{name} #{inspect other}"
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
  defp pp(%{text: text}), do: text
  defp pp(other), do: IO.inspect other
end
