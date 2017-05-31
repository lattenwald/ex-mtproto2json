defmodule Mtproto2json.Workers do
  require Logger
  use Supervisor

  # interface
  def start_link(port) do
    Logger.info "#{__MODULE__} starting"

    Supervisor.start_link(
      __MODULE__,
      port,
      name: __MODULE__
    )
  end

  def start_child(name, session) do
    Supervisor.start_child(__MODULE__, [name, session])
  end

  # callbacks
  def init(port) do
    children = [ supervisor(Mtproto2json.WorkerSup, [port], restart: :transient) ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
