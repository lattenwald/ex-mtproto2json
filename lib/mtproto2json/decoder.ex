defmodule Mtproto2json.Decoder do
  require Logger
  use GenServer

  alias Mtproto2json.Decoder.Helpers
  alias Mtproto2json.Type.Chat
  alias Mtproto2json.Type.Channel
  alias Mtproto2json.Type.Event

  alias Mtproto2json.Decoder.Persisted

  defstruct manager: nil, name: nil

  # interface
  def start_link(name) do
    Logger.info "#{__MODULE__} starting, named #{inspect name}"
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def incoming(name, data=%{}) do
    decoded = Helpers.decode(data)
    process(name, decoded)
  end

  def find(name, :users, id), do: Persisted.find_user(name, id)
  def find(name, :chats, id), do: Persisted.find_chat(name, id)

  def get_manager(name) do
    GenServer.call(via_tuple(name), :get_manager)
  end

  def alive?(name) do
    name |> via_tuple |> Process.alive?
  end

  def merge_dialogs(name, map) do
    GenServer.call(via_tuple(name), {:merge_dialogs, map})
  end

  # callbacks
  def init(name) do
    {:ok, manager} = :gen_event.start_link([])
    {:ok, %__MODULE__{manager: manager, name: name}}
  end

  def handle_call({:incoming, data}, _from, state=%{name: name}) do
    Persisted.incoming(name, :users, data[:users])
    Persisted.incoming(name, :chats, data[:chats])

    if data[:updates] != nil do
      send self(), {:updates, data.updates}
    end

    {:reply, :ok, state}
  end

  def handle_call({:merge_dialogs, data}, _from, state=%{name: name}) do
    Persisted.incoming(name, :users, data[:users])
    Persisted.incoming(name, :chats, data[:chats])
    {:reply, :ok, state}
  end

  def handle_call(:get_manager, _from, state=%{manager: manager}) do
    {:reply, manager, state}
  end

  def handle_info({:updates, updates}, state=%{manager: manager, name: name}) do
    Logger.debug "processing updates #{inspect updates}"

    updates
    |> Stream.filter(&not(is_nil(&1)))
    |> Stream.map(&Map.put(&1, :sender,    get_sender(state, &1)))
    |> Stream.map(&Map.put(&1, :recipient, get_recipient(state, &1)))
    |> Stream.map(&Map.put(&1, :replyto,   get_replyto(&1)))
    |> Stream.map(fn m=%{sender: s, recipient: r} ->
      if is_nil(s) or is_nil(r), do: Logger.warn inspect m
      m
    end)
    |> Stream.map(&:gen_event.sync_notify(manager, %Event{name: name, data: &1}))
    |> Stream.run

    {:noreply, state}
  end

  # helpers
  defp via_name(name), do: {Mtproto2json.registry(), {:decoder, name}}
  defp via_tuple(name), do: {:via, Registry, via_name(name)}

  defp process(name, data) when is_map(data) do
    GenServer.call(via_tuple(name), {:incoming, data})
  end

  defp process(_name, data) do
    Logger.debug "not processing #{inspect data}"
  end

  defp get_sender(_state, %{out: true}), do: :self
  defp get_sender(%{name: name}, %{user_id: id}) when not(is_nil id), do: Persisted.find_user(name, id)
  defp get_sender(%{name: name}, %{from_id: id}) when not(is_nil id), do: Persisted.find_user(name, id)
  defp get_sender(%{name: name}, %{to_id: %{"_cons" => "peerChannel", "channel_id" => id}})
  when not(is_nil id), do: Persisted.find_chat(name, id)

  defp get_sender(_state, stuff) do
    Logger.warn "failed detecting sender #{inspect stuff}"
    nil
  end

  def get_recipient(
    %{name: name},
    %{to_id: %{"_cons" => "peerChannel", "channel_id" => id}}
  ), do: Persisted.find_chat(name, id)
  def get_recipient(
    %{name: name},
    %{to_id: %{"_cons" => "peerUser", "user_id" => id}}
  ), do: Persisted.find_user(name, id)
  def get_recipient(%{name: name}, %{out: true, user_id: id}) when not(is_nil id), do: Persisted.find_user(name, id)
  def get_recipient(_state, %{user_id: id}) when not(is_nil id), do: :self
  def get_recipient(%{name: name}, %{chat_id: id}) when not(is_nil id), do: Persisted.find_chat(name, id)
  def get_recipient(_state, other) do
    Logger.warn "failed detecting recipient #{inspect other}"
    nil
  end

  def get_replyto(%{recipient: r = %Chat{}}), do: r
  def get_replyto(%{recipient: r = %Channel{}}), do: r
  def get_replyto(%{sender: :self, recipient: r}), do: r
  def get_replyto(%{sender: s}), do: s

end
