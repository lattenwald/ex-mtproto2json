defmodule Mtproto2json.Decoder do
  require Logger
  use GenServer

  alias Mtproto2json.Decoder.Helpers

  defstruct users: %{}, channels: %{}, callback: nil

  # interface
  def start_link(name, cb) do
    Logger.info "#{__MODULE__} starting"
    GenServer.start_link(__MODULE__, cb, name: via_tuple(name))
  end

  def incoming(name, data=%{}) do
    decoded = Helpers.decode(data)
    process(name, decoded)
  end

  def get_state(name) do
    GenServer.call(via_tuple(name), :get_state)
  end

  # callbacks
  def init(cb) do
    {:ok, %__MODULE__{callback: cb}}
  end

  def handle_call({:incoming, data}, _from, state) do
    new_users = Map.merge(state.users, data[:users] || %{})
    new_channels = Map.merge(state.channels, data[:channels] || %{})

    new_state = state
    |> Map.put(:users, new_users)
    |> Map.put(:channels, new_channels)

    if data[:updates] != nil do
      send self(), {:updates, data.updates}
    end

    {:reply, :ok, new_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:updates, updates}, state=%{callback: cb}) do
    Logger.debug "processing updates #{inspect updates}"

    updates
    |> Stream.filter(&not(is_nil(&1)))
    |> Stream.map(&Map.put(&1, :sender,    get_sender(state, &1)))
    |> Stream.map(&Map.put(&1, :recipient, get_recipient(state, &1)))
    |> Enum.map(&cb.(&1))

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
  defp get_sender(state, stuff) do
    Logger.warn "not getting sender for #{inspect stuff}"
    Logger.warn "in state #{inspect state}"
  end

  def get_recipient(
    %{channels: channels},
    %{to_id: %{"_cons" => "peerChannel", "channel_id" => id}}
  ), do: channels[id]
  def get_recipient(
    %{users: users},
    %{out: true, user_id: id}
  ), do: users[id]
  def get_recipient(
    %{users: users},
    %{user_id: id}
  ) when not(is_nil id), do: :self
  def get_recipient(%{channels: channels}, %{chat_id: id}), do: channels[id]

end
