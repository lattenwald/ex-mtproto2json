defmodule Mtproto2json.WorkerSup do
  require Logger
  use Supervisor

  # interface
  def start_link(port, name, handler, session) do
    Logger.info "#{__MODULE__} starting, named #{inspect name}"

    Supervisor.start_link(
      __MODULE__,
      [port, name, handler, session]
    )
  end

  # callbacks
  def init([port, name, handler, session]) do
    children = [
      worker(Mtproto2json.Decoder, [name, handler]),
      supervisor(Mtproto2json.Connector.Sup, [port, name, session], restart: :transient)
    ]

    supervise(children, strategy: :one_for_one)
  end
end
