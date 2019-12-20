require Logger

defmodule Certstream.WebsocketServer do
  use GenServer

  # GenServer callback
  def init(args) do {:ok, args} end

  # /example.json handler
  def init(req, [:example_json]) do
    res = :cowboy_req.reply(
      200,
      %{'content_type' => 'application/json'},
      Certstream.CertifcateBuffer.get_example_json(),
      req
    )
    {:ok, res, %{}}
  end

  # /latest.json handler
  def init(req, [:latest_json]) do
    res = :cowboy_req.reply(
      200,
      %{'content_type' => 'application/json'},
      Certstream.CertifcateBuffer.get_latest_json(),
      req
    )
    {:ok, res, %{}}
  end

  # /stats handler
  def init(req, [:stats]) do
    processed_certs = Certstream.CertifcateBuffer.get_processed_certificates
    client_json = Certstream.ClientManager.get_clients_json

    workers = DynamicSupervisor.which_children(WatcherSupervisor)
      |> Enum.reduce(%{}, fn {:undefined, pid, :worker, _module}, acc ->
          state = :sys.get_state pid
          Map.put(acc, state[:url], state[:processed_count] || 0)
         end)

    response = %{}
               |> Map.put(:processed_certificates, processed_certs)
               |> Map.put(:current_users, client_json)
               |> Map.put(:workers, workers)
               |> Jason.encode!
               |> Jason.Formatter.pretty_print

    res = :cowboy_req.reply(
      200,
      %{'content_type' => 'application/json'},
      response,
      req
    )
    {:ok, res, %{}}
  end

  # / handler
  def init(req, state) do
    # If we have a websocket request, do the thing, otherwise just host our main HTML
    if Map.has_key?(req.headers, "upgrade") do
      Logger.debug("New client connected #{inspect req.peer}")
      {
        :cowboy_websocket,
        req,
        %{
          :is_websocket => true,
          :connect_time => DateTime.utc_now,
          :ip_address => req.peer |> elem(0) |> :inet_parse.ntoa |> to_string,
          :headers => req.headers
        },
        %{:compress => true}
      }
    else
      res = :cowboy_req.reply(
        200,
        %{'content_type' => 'text/html'},
        File.read!("html/dist/index.html"),
        req
      )
      {:ok, res, state}
    end
  end

  def terminate(_reason, _partial_req, state) do
    if state[:is_websocket] do
      Logger.debug("Client disconnected #{inspect state.ip_address}")
      Certstream.ClientManager.remove_client(self())
    end
  end

  def websocket_init(state) do
    Certstream.ClientManager.add_client(self(), state)
    {:ok, state}
  end

  def websocket_handle(frame, state) do
    Logger.debug("Client sent message #{inspect frame}")
    {:ok, state}
  end

  def websocket_info({:mail, box_pid, payload, _message_count, message_drop_count}, state) do
    if message_drop_count > 0 do
      Logger.warn("Message drop count greater than 0 -> #{message_drop_count}")
    end

    Logger.debug(fn -> "Sending client #{length(payload |> List.flatten)} client frames" end)

    # Reactive our pobox active mode
    :pobox.active(box_pid, fn(msg, _) -> {{:ok, msg}, :nostate} end, :nostate)

    {
      :reply,
      payload |> Enum.map(fn message -> message |> Enum.map(&({:text, &1})) end) |> List.flatten,
      state
    }
  end

  def start_link(_opts) do
    Logger.info("Starting web server on port #{get_port()}...")
    :cowboy.start_clear(
      :websocket_server,
      [{:port, get_port()}],
      %{
        :env => %{
          :dispatch => :cowboy_router.compile([
            {:_,
              [
                {"/", __MODULE__, []},
                {"/example.json", __MODULE__, [:example_json]},
                {"/latest.json", __MODULE__, [:latest_json]},
                {"/static/[...]", :cowboy_static, {:dir, "html/dist/static/"}},
                {"/#{System.get_env(~s(STATS_URL)) || 'stats'}", __MODULE__, [:stats]}
              ]}
          ])
        },
      }
    )

    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      name: __MODULE__
    }
  end

  defp get_port do
    case System.get_env("PORT") do
      nil -> 4000
      port_string ->  port_string |> Integer.parse |> elem(0)
    end
  end

end
