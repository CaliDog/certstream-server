defmodule Certstream do
  use Application

  def start(_type, _args) do
    children = [
      # Web services
      Certstream.WebsocketServer,

      # Agents
      Certstream.ClientManager,
      Certstream.CertifcateBuffer,

      # Watchers
      {DynamicSupervisor, name: WatcherSupervisor, strategy: :one_for_one}
    ]

    supervisor_info = Supervisor.start_link(children, strategy: :one_for_one)

    Certstream.CTWatcher.start_and_link_watchers(name: WatcherSupervisor)

    supervisor_info
  end
end