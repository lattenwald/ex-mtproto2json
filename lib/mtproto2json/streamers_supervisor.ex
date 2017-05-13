defmodule Mtproto2json.StreamersSupervisor do
  require Logger
  use Supervisor

  @name __MODULE__

  # interface
  def start_link() do
    Logger.info "#{__MODULE__} starting"
    Supervisor.start_link(__MODULE__, nil, name: @name)
  end

  def start_child(port, cb) do
    Supervisor.start_child(@name, [port, cb])
  end

  # callbacks
  def init(_) do
    children = [worker(Mtproto2json.Sup, [])]

    supervise(
      children,
      strategy: :simple_one_for_one
    )
  end
end
