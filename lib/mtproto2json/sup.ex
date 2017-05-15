defmodule Mtproto2json.Sup do
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

  def start_child(session, cb, name) do
    Supervisor.start_child(__MODULE__, [session, cb, name])
  end

  # callbacks
  def init(port) do
    children = [ worker(Mtproto2json.Connector, [port]) ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
