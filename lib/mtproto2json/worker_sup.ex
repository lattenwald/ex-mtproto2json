defmodule Mtproto2json.WorkerSup do
  require Logger
  use Supervisor

  # interface
  def start_link(port, name, session, persist) do
    Logger.info "#{__MODULE__} starting, named #{inspect name}"

    Supervisor.start_link(
      __MODULE__,
      [port, name, session, persist]
    )
  end

  # callbacks
  def init([port, name, session, persist]) do
    children = [
      supervisor(Mtproto2json.Decoder.Persisted, [name, persist], restart: :transient),
      worker(Mtproto2json.Decoder, [name], restart: :transient),
      supervisor(Mtproto2json.Connector.Sup, [port, name, session], restart: :transient)
    ]

    supervise(children, strategy: :one_for_one)
  end
end
