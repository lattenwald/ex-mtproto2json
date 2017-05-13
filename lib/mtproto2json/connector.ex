defmodule Mtproto2json.Connector do
  require Logger
  use GenServer

  defstruct socket: nil, callback: nil

  @send_timeout Application.get_env(:mtproto2json, :send_timeout, 5000)
  @conn_timeout Application.get_env(:mtproto2json, :conn_timeout, 5000)

  # interface
  def start_link(port, cb) do
    Logger.info "#{__MODULE__} starting on port #{port}"
    GenServer.start_link(
      __MODULE__, [port, cb], name: via_tuple(port)
    )
  end

  def send(port, data)
  when is_integer(port) do
    GenServer.call(via_tuple(port), {:send, data})
  end

  def send(pid, data)
  when is_pid(pid) do
    GenServer.call(pid, {:send, data})
  end

  # callbacks
  def init([port, cb]) do
    {:ok, sock} = :gen_tcp.connect(
      'localhost', port,
      [:binary, {:active, true}, {:packet, :line}, {:send_timeout, @send_timeout}],
      @conn_timeout
    )
    {:ok, %__MODULE__{socket: sock, callback: cb}}
  end

  def handle_call({:send, data}, _from, state=%{socket: sock}) do
    resp = :gen_tcp.send(sock, data)
    {:reply, resp, state}
  end

  def handle_info({:tcp_closed, in_sock}, %{socket: sock})
  when in_sock == sock do
    Logger.warn "socket closed"
    {:stop, :socket_closed, nil}
  end

  def handle_info({:tcp, in_sock, data}, state=%{socket: sock, callback: cb})
  when in_sock == sock do
    res = Poison.decode!(data)
    Logger.debug "[tcp] #{inspect res}"
    cb.(res)
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.warn "unexpected info: #{inspect info}"
    {:noreply, state}
  end

  # helpers
  defp via_name(port), do: {Mtproto2json.registry(), {:connector, port}}
  defp via_tuple(port), do: {:via, Registry, via_name(port)}
end
