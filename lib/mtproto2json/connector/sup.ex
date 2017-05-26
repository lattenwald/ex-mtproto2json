defmodule Mtproto2json.Connector.Sup do
  require Logger
  use Supervisor

  # interface
  def start_link(port, name, session) do
    Logger.info "#{__MODULE__} starting for port #{port}, name #{inspect name}"
    Supervisor.start_link(
      __MODULE__,
      [port, name, session],
      name: via_tuple(name)
    )
  end

  def stop(name, reason \\ :shutdown) do
    Supervisor.stop(via_tuple(name), reason)
  end

  # callbacks
  def init([port, name, session]) do
    children = [
      worker(Mtproto2json.Connector, [port, name, session]),
      worker(Mtproto2json.Connector.Watchdog, [name]),
    ]

    supervise(children, strategy: :one_for_all)
  end

  # helpers
  defp via_name(port), do: {Mtproto2json.registry(), {:connector_sup, port}}
  defp via_tuple(port), do: {:via, Registry, via_name(port)}
end
