defmodule Certstream do
  @moduledoc """
  Certstream is a service for watching CT servers, parsing newly discovered certificates,
  and publishing them to AWS SNS.
  """
  use Application

  def start(_type, _args) do
    children = [
      # Web services (health check only)
      Certstream.WebsocketServer,

      # Certificate processing
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
