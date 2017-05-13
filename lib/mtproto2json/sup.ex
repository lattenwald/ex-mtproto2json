defmodule Mtproto2json.Sup do
  require Logger
  use Supervisor

  # interface
  def start_link(port, cb) do
    Logger.info "#{__MODULE__} starting"

    Supervisor.start_link(
      __MODULE__,
      [port, cb]
    )
  end

  # callbacks
  def init([port, cb]) do
    children = [
      worker(Mtproto2json.Runner, [port]),
      worker(Mtproto2json.Connector, [port, cb]),
    ]

    supervise(children, strategy: :rest_for_one)
  end
end
