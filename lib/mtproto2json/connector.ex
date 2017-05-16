defmodule Mtproto2json.Connector do
  require Logger
  use GenServer
  import Kernel, except: [send: 2]

  defstruct socket: nil, callback: nil, waiting: %{}, next_id: 1

  @send_timeout Application.get_env(:mtproto2json, :send_timeout, 5000)
  @conn_timeout Application.get_env(:mtproto2json, :conn_timeout, 5000)
  @buffer_limit 16000000
  @retry_connect_timeout 500

  # interface
  def start_link(port, session, cb, name \\ "noname") do
    Logger.info "#{__MODULE__} starting, named #{inspect name}"
    Logger.debug "params: #{inspect port}, #{inspect session}, #{inspect cb}, #{inspect name}"
    res = {:ok, _pid} = GenServer.start_link(
      __MODULE__, [port, cb], name: via_tuple(name)
    )
    call(name, session) |> IO.inspect
    res
  end

  def send(name, data=%{}) do
    data = Poison.encode!(data) <> "\n"
    GenServer.call(via_tuple(name), {:send, data})
  end

  def call(name, data=%{}) do
    GenServer.call(via_tuple(name), {:call, data})
  end

  # callbacks
  def init([port, cb]) do
    with {:ok, sock} <- :gen_tcp.connect(
           'localhost', port,
           [:binary, {:active, true}, {:packet, :line}, {:buffer, @buffer_limit}, {:send_timeout, @send_timeout}],
           @conn_timeout
         ) do
      {:ok, %__MODULE__{socket: sock, callback: cb}}
    else
      err = {:error, :econnrefused} ->
        :timer.sleep @retry_connect_timeout
        {:stop, err}

      err -> {:stop, err}
    end
  end

  def handle_call({:send, data}, _from, state=%{socket: sock}) do
    Logger.debug "[sending] #{inspect data}"
    resp = :gen_tcp.send(sock, data)
    {:reply, resp, state}
  end

  def handle_call({:call, data}, from, state=%{socket: sock, next_id: id}) do
    Logger.debug "[calling] #{inspect data}"
    data = data |> Map.put(:id, id) |> Poison.encode!
    :ok = :gen_tcp.send(sock, data <> "\n")
    waiting = state.waiting |> Map.put(id, from)
    {:noreply, %{state | waiting: waiting, next_id: id+1}}
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

defmodule Mtproto2json.Connector.Sup do
  require Logger
  use Supervisor

  # interface
  def start_link(port, session, cb, name \\ "noname") do
    Logger.info "#{__MODULE__} starting for port #{port}, name #{inspect name}"
    Supervisor.start_link(
      __MODULE__,
      [port, session, cb, name],
      name: via_tuple(name)
    )
  end

  def stop(name, reason \\ :shutdown) do
    Supervisor.stop(via_tuple(name), reason)
  end

  # callbacks
  def init([port, session, cb, name]) do
    children = [
      worker(Mtproto2json.Connector, [port, session, cb, name]),
      worker(Mtproto2json.Connector.Watchdog, [name]),
    ]

    supervise(children, strategy: :one_for_all)
  end

  # helpers
  defp via_name(port), do: {Mtproto2json.registry(), {:connector_sup, port}}
  defp via_tuple(port), do: {:via, Registry, via_name(port)}
end

defmodule Mtproto2json.Connector.Watchdog do
  require Logger
  use GenServer

  @watchdog_period 60000

  # interface
  def start_link(name) do
    Logger.info "#{__MODULE__} starting for name #{inspect name}"
    GenServer.start_link(__MODULE__, name)
  end

  # callbacks
  def init(name) do
    send self(), :watchdog
    :timer.send_interval(@watchdog_period, :watchdog)
    {:ok, name}
  end

  def handle_info(:watchdog, name) do
    msg = Mtproto2json.Msg.updateStatus()
    res = Mtproto2json.Connector.call(name, msg) |> Mtproto2json.Decoder.Helpers.decode
    Logger.info "#{name} updating status: #{inspect res}"
    {:noreply, name}
  end

  def handle_info(info, name) do
    Logger.warn "unexpected info: #{inspect info}"
    {:noreply, name}
  end
end
