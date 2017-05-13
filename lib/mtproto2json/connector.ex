defmodule Mtproto2json.Connector do
  require Logger
  use GenServer
  import Kernel, except: [send: 2]

  defstruct socket: nil, callback: nil, waiting: %{}

  @send_timeout Application.get_env(:mtproto2json, :send_timeout, 5000)
  @conn_timeout Application.get_env(:mtproto2json, :conn_timeout, 5000)
  @buffer_limit 16000000

  # interface
  def start_link(port, cb) do
    Logger.info "#{__MODULE__} starting on port #{port}"
    GenServer.start_link(
      __MODULE__, [port, cb], name: via_tuple(port)
    )
  end

  def send(addr, data)
  when is_map(data) do
    send(addr, Poison.encode!(data))
  end

  def send(port, data)
  when is_integer(port) do
    data = case String.last(data) do
             "\n" -> data
             _ -> data <> "\n"
           end
    GenServer.call(via_tuple(port), {:send, data})
  end

  def call(port, data)
  when is_integer(port) do
    call(via_tuple(port), data)
  end

  def call(addr, data)
  when is_map(data) do
    # TODO: generate id properly
    # TODO: check if id is free
    id = :rand.uniform(1000000)
    data = data |> Map.put(:id, id) |> Poison.encode!
    GenServer.call(addr, {:call, id, data <> "\n"})
  end

  # callbacks
  def init([port, cb]) do
    {:ok, sock} = :gen_tcp.connect(
      'localhost', port,
      [:binary, {:active, true}, {:packet, :line}, {:buffer, @buffer_limit}, {:send_timeout, @send_timeout}],
      @conn_timeout
    )
    {:ok, %__MODULE__{socket: sock, callback: cb}}
  end

  def handle_call({:send, data}, _from, state=%{socket: sock}) do
    Logger.debug "[sending] #{inspect data}"
    resp = :gen_tcp.send(sock, data)
    {:reply, resp, state}
  end

  def handle_call({:call, id, data}, from, state=%{socket: sock}) do
    Logger.debug "[calling] #{inspect data}"
    :ok = :gen_tcp.send(sock, data)
    waiting = state.waiting |> Map.put(id, from)
    {:noreply, %{state | waiting: waiting}}
  end

  def handle_info({:tcp_closed, in_sock}, %{socket: sock})
  when in_sock == sock do
    Logger.warn "socket closed"
    {:stop, :socket_closed, nil}
  end

  def handle_info({:tcp, in_sock, data}, state=%{socket: sock, callback: cb, waiting: waiting})
  when in_sock == sock do
    Logger.debug "[tcp] #{data}"
    new_state =
      with {:ok, res} <- Poison.decode(data) do
        case waiting[res["id"]] do
          nil ->
            cb.(res)
            state
          waiter ->
            GenServer.reply(waiter, res)
            waiting = state.waiting |> Map.delete(res["id"])
            %{state | waiting: waiting}
        end
      else
        err ->
          Logger.warn "Poison decode error: #{inspect err}"
          state
      end
    {:noreply, new_state}
  end

  def handle_info(info, state) do
    Logger.warn "unexpected info: #{inspect info}"
    {:noreply, state}
  end

  # helpers
  defp via_name(port), do: {Mtproto2json.registry(), {:connector, port}}
  defp via_tuple(port), do: {:via, Registry, via_name(port)}
end
