defmodule Mtproto2json.Application do
  use Application

  @port Application.get_env(:mtproto2json, :port, 1543)

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:unique, Mtproto2json.registry()]),
      supervisor(Mtproto2json.Workers, [@port]),
      worker(Mtproto2json.Runner, [@port]),
    ]

    opts = [strategy: :rest_for_one, name: Mtproto2json.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
