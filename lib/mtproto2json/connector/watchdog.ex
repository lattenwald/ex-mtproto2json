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
