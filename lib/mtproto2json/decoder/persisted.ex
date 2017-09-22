defmodule Mtproto2json.Decoder.Persisted do
  require Logger
  use Supervisor

  alias Mtproto2json.Decoder.Persisted.Data

  ### interface
  def start_link(name, persist \\ false) do
    Logger.info "#{__MODULE__} starting, named #{inspect name}"

    Supervisor.start_link(__MODULE__, [name, persist], name: via_tuple(name))
  end

  def find_user(name, username) when is_binary(username), do: Data.find({:users, name}, & &1.username == username)

  def find_user(name, id) when is_integer(id), do: Data.get({:users, name}, id)

  def find_chat(name, id) when is_integer(id), do: Data.get({:chats, name}, id)

  def incoming(_name, _type, nil), do: :ok
  def incoming(name, type, data), do: Data.incoming({type, name}, data)

  ### callbacks
  def init([name, persist]) do
    children = [
      worker(Data, [{:users, name}, persist], id: {Data, :users}),
      worker(Data, [{:chats, name}, persist], id: {Data, :chats}),
    ]

    supervise(children, strategy: :one_for_one)
  end

  ### helpers
  defp via_name(name), do: {Mtproto2json.registry(), {:decoder_persisted, name}}
  defp via_tuple(name), do: {:via, Registry, via_name(name)}
end

defmodule Mtproto2json.Decoder.Persisted.Data do
  require Logger
  use GenServer, restart: :permanent

  ### interface
  def start_link(tup, persist) do
    Logger.info "#{__MODULE__} starting for #{inspect tup}"
    GenServer.start_link(__MODULE__, [tup, persist], name: via_tuple(tup))
  end

  def get(tup, id) do
    case :ets.lookup(table_name(tup), id) do
      [{^id, item}] -> item
      []            -> nil
    end
  end

  def find(tup, fun) do
    :ets.foldl(fn
      {_id, item}, nil -> if fun.(item), do: item, else: nil
      _, item          -> item
    end, nil, table_name(tup))
  end

  def incoming(tup={type, name}, data=%{}) do
    for {id, val} <- data do
      old = get(tup, id)
      cond do
        old == nil ->
          Logger.debug "new #{type} for #{name}: #{inspect data}"
          add(tup, id, val)

        old.access_hash == nil and val.access_hash != nil ->
          Logger.debug "access_hash #{type} for #{name}: #{inspect data}"
          add(tup, id, val)

        true -> :ignore
      end
    end
  end

  ### callbacks
  def init([tup, persist]) do
    ets = :ets.new(table_name(tup), [:set, :named_table, :protected])

    if persist do
      {:ok, dets} = :dets.open_file(table_name(tup), type: :set)

      case :dets.to_ets(dets, ets) do
        {:error, err} -> {:stop, err}
        _             -> {:ok, {tup, dets}}
      end
    else
      {:ok, {tup, nil}}
    end
  end

  def handle_call({:add, id, val}, _from, state={tup, dets}) do
    data = {id, val}
    if not(is_nil dets), do: :ok = :dets.insert(dets, data)
    true = :ets.insert(table_name(tup), data)
    {:reply, :ok, state}
  end

  ### helpers
  defp via_name(tup), do: {Mtproto2json.registry(), {:decoder_persisted, tup}}
  defp via_tuple(tup), do: {:via, Registry, via_name(tup)}

  defp table_name({type, name}), do: String.to_atom("#{type}_#{name}")

  defp add(tup, id, val) do
    GenServer.call(via_tuple(tup), {:add, id, val})
  end

end
