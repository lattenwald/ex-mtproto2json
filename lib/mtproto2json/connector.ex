defmodule Mtproto2json.Connector do
  require Logger
  use GenServer
  import Kernel, except: [send: 2]

  alias Mtproto2json.Decoder, as: Dec

  defstruct socket: nil, name: nil, waiting: %{}, next_id: 1

  @send_timeout Application.get_env(:mtproto2json, :send_timeout, 5000)
  @conn_timeout Application.get_env(:mtproto2json, :conn_timeout, 5000)
  @buffer_limit 16000000
  @retry_connect_timeout 500

  # interface
  def start_link(port, name, session) do
    Logger.info "#{__MODULE__} starting, named #{inspect name}"

    res = {:ok, _pid} = GenServer.start_link(
      __MODULE__, [port, name], name: via_tuple(name)
    )
    call(name, session)
    res
  end

  def send(name, data=%{}, timeout \\ 5000) do
    data = Poison.encode!(data) <> "\n"
    GenServer.call(via_tuple(name), {:send, data}, timeout)
  end

  def call(name, data=%{}, timeout \\ 5000) do
    resp = GenServer.call(via_tuple(name), {:call, data}, timeout)
    Dec.incoming(name, resp)
    resp
  end

  # callbacks
  def init([port, name]) do
    :gen_tcp.connect(
      'localhost', port,
      [:binary, {:active, true}, {:packet, :line}, {:buffer, @buffer_limit}, {:send_timeout, @send_timeout}],
      @conn_timeout
    )
    |> case do
         {:ok, sock} ->
           {:ok, %__MODULE__{socket: sock, name: name}}

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

  def handle_info({:tcp, in_sock, data}, state=%{socket: sock, name: name, waiting: waiting})
  when in_sock == sock do
    Logger.debug "[tcp] #{data}"
    new_state =
      with {:ok, res} <- Poison.decode(data) do
        case waiting[res["id"]] do
          nil ->
            Dec.incoming(name, res)
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
