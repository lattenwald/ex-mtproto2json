defmodule Mtproto2json.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:unique, Mtproto2json.registry()]),
      supervisor(Mtproto2json.StreamersSupervisor, [])
    ]

    opts = [strategy: :rest_for_one, name: Mtproto2json.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
