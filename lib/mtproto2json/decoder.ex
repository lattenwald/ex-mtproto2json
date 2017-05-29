defmodule Mtproto2json.Decoder do
  require Logger
  use GenServer

  alias Mtproto2json.Decoder.Helpers
  alias Mtproto2json.Type.Chat
  alias Mtproto2json.Type.Channel
  alias Mtproto2json.Type.Event

  defstruct users: %{}, chats: %{}, manager: nil, name: nil

  # interface
  def start_link(name, module) do
    Logger.info "#{__MODULE__} starting, named #{inspect name}"
    GenServer.start_link(__MODULE__, [name, module], name: via_tuple(name))
  end

  def incoming(name, data=%{}) do
    decoded = Helpers.decode(data)
    process(name, decoded)
  end

  def find(name, :users, username)
  when is_binary(username) do
    GenServer.call(via_tuple(name), {:find_username, username})
  end

  def find(name, what, id)
  when what in [:chats, :users] do
    GenServer.call(via_tuple(name), {:find, what, id})
  end

  def get_state(name) do
    GenServer.call(via_tuple(name), :get_state)
  end

  def alive?(name) do
    name |> via_tuple |> Process.alive?
  end

  # callbacks
  def init([name, module]) do
    {:ok, manager} = GenEvent.start_link([])
    case GenEvent.add_handler(manager, module, []) do
      :ok              -> {:ok, %__MODULE__{manager: manager, name: name}}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:incoming, data}, _from, state) do
    merger = fn
      _k, %{access_hash: nil}, v2 -> v2
      _k, v1, _v2 -> v1
    end

    new_users = Map.merge(state.users, data[:users] || %{}, merger)
    new_chats = Map.merge(state.chats, data[:chats] || %{}, merger)

    new_state = state
    |> Map.put(:users, new_users)
    |> Map.put(:chats, new_chats)

    if data[:updates] != nil do
      send self(), {:updates, data.updates}
    end

    {:reply, :ok, new_state}
  end

  def handle_call({:find, what, id}, _from, state) do
    res = case what do
            :chats -> state.chats[id]
            :users -> state.users[id]
            _      -> nil
          end
    {:reply, res, state}
  end

  def handle_call({:find_username, username}, _from, state) do
    username = String.downcase(username)

    user = state.users
    |> Map.values
    |> Enum.filter(&not(is_nil &1.username))
    |> Enum.filter(&(String.downcase(&1.username) == username))
    |> List.first

    {:reply, user, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
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
    |> Stream.map(&GenEvent.sync_notify(manager, %Event{name: name, data: &1}))
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
  defp get_sender(%{users: users},  %{user_id: id}) when not(is_nil id), do: users[id]
  defp get_sender(%{users: users},  %{from_id: id}) when not(is_nil id), do: users[id]
  defp get_sender(
    %{chats: chats},
    %{to_id: %{"_cons" => "peerChannel", "channel_id" => id}}
  ) when not(is_nil id) do
    chats[id]
  end
  defp get_sender(_state, stuff) do
    Logger.warn "failed detecting sender #{inspect stuff}"
    nil
  end

  def get_recipient(
    %{chats: chats},
    %{to_id: %{"_cons" => "peerChannel", "channel_id" => id}}
  ), do: chats[id]
  def get_recipient(
    %{users: users},
    %{to_id: %{"_cons" => "peerUser", "user_id" => id}}
  ), do: users[id]
  def get_recipient(%{users: users}, %{out: true, user_id: id}) when not(is_nil id), do: users[id]
  def get_recipient(_state, %{user_id: id}) when not(is_nil id), do: :self
  def get_recipient(%{chats: chats}, %{chat_id: id}) when not(is_nil id), do: chats[id]
  def get_recipient(_state, other) do
    Logger.warn "failed detecting recipient #{inspect other}"
    nil
  end

  def get_replyto(%{recipient: r = %Chat{}}), do: r
  def get_replyto(%{recipient: r = %Channel{}}), do: r
  def get_replyto(%{sender: :self, recipient: r}), do: r
  def get_replyto(%{sender: s}), do: s

end
