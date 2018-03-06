defmodule Certstream do
  use Application

  def start(_type, _args) do
    supervisor_info = Certstream.Supervisor.start_link(name: CertstreamSupervisor)

    Certstream.CTWatcher.start_and_link_watchers(name: WatcherSupervisor)

    supervisor_info
  end
end