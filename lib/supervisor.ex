defmodule Certstream.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do

    children = [
      # Web services
      Certstream.WebsocketServer,

      # Agents
      Certstream.ClientManager,
      Certstream.CertifcateBuffer,

      # Watchers
      {DynamicSupervisor, name: WatcherSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

end