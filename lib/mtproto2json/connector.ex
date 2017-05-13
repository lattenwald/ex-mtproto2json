defmodule Mtproto2json.Connector do
  require Logger
  use GenServer
  import Kernel, except: [send: 2]

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

  # callbacks
  def init([port, cb]) do
    {:ok, sock} = :gen_tcp.connect(
      'localhost', port,
      [:binary, {:active, true}, {:packet, :line}, {:buffer, 1000000}, {:send_timeout, @send_timeout}],
      @conn_timeout
    )
    {:ok, %__MODULE__{socket: sock, callback: cb}}
  end

  def handle_call({:send, data}, _from, state=%{socket: sock}) do
    Logger.debug "[sending] #{inspect data}"
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
    Logger.debug "[tcp] #{data}"
    with {:ok, res} <- Poison.decode(data) do
      cb.(res)
    else
      err ->
        Logger.warn "Poison decode error: #{inspect err}"
    end
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
