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
    children = [ supervisor(Mtproto2json.Connector.Sup, [port], restart: :transient) ]

    supervise(children, strategy: :simple_one_for_one)
  end
end

# {:inlineMarkup,
#  [
#    %{data: "bXNnIC0yNDEyNzAxNTQ=",
#      text: "Windmill"},
#    %{data: "bXNnIC0xMDAxMDcyNzI1Mzkx",
#      text: "🥔 ответики 🥔"},
#    %{data: "bXNnIDEyMjI0NzE3OA==",
#      text: "@lattenwald"},
#    %{data: "bXNnIC0xMDAxMTE1Nzc1NTA2",
#      text: "Aperture Labs Test Facility"},
#    %{data: "bXNnIDE2ODc1NDU5MQ==",
#      text: "@mnikat"}]}
