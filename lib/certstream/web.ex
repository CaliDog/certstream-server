require Logger

defmodule Certstream.WebsocketServer do
  @moduledoc """
  The main web services GenServer, responsible for spinning up cowboy and encapsulates
  all logic for web routes/websockets.
  """
  use GenServer
  use Instruments


  @full_stream_url Application.fetch_env!(:certstream, :full_stream_url)
  @domains_only_url Application.fetch_env!(:certstream, :domains_only_url)

  # GenServer callback
  def init(args) do {:ok, args} end

  # /example.json handler
  def init(req, [:example_json]) do
    res = :cowboy_req.reply(200, %{'content-type' => 'application/json'},
                            Certstream.CertifcateBuffer.get_example_json(), req)
    {:ok, res, %{}}
  end

  # /latest.json handler
  def init(req, [:latest_json]) do
    res = :cowboy_req.reply(200, %{'content-type' => 'application/json'},
                            Certstream.CertifcateBuffer.get_latest_json(), req)
    {:ok, res, %{}}
  end

  # /stats handler
  def init(req, [:stats]) do
    processed_certs = Certstream.CertifcateBuffer.get_processed_certificates
    client_json = Certstream.ClientManager.get_clients_json

    workers = WatcherSupervisor
                |> DynamicSupervisor.which_children
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
      %{'content-type' => 'application/json'},
      response,
      req
    )
    {:ok, res, %{}}
  end

  # / handler
  def init(req, state) do
    # If we have a websocket request, do the thing, otherwise just host our main HTML
    if Map.has_key?(req.headers, "upgrade") do
      Logger.debug(fn -> "New client connected #{inspect req.peer}" end)
      {
        :cowboy_websocket,
        req,
        %{
          :is_websocket => true,
          :connect_time => DateTime.utc_now,
          :ip_address => req.peer |> elem(0) |> :inet_parse.ntoa |> to_string,
          :headers => req.headers,
          :path => req.path
        },
        %{:compress => true}
      }
    else
      Instruments.increment("certstream.index_load", 1, tags: ["ip:#{state[:ip_address]}"])
      res = :cowboy_req.reply(
        200,
        %{'content-type' => 'text/html'},
        File.read!("frontend/dist/index.html"),
        req
      )
      {:ok, res, state}
    end
  end

  def terminate(_reason, _partial_req, state) do
    if state[:is_websocket] do
      Instruments.increment("certstream.websocket_disconnect", 1, tags: ["ip:#{state[:ip_address]}"])
      Logger.debug(fn -> "Client disconnected #{inspect state.ip_address}" end)
      Certstream.ClientManager.remove_client(self())
    end
  end

  def websocket_init(state) do
    Logger.info("Client connected #{inspect state.ip_address}")
    Instruments.increment("certstream.websocket_connect", 1, tags: ["ip:#{state[:ip_address]}"])
    Certstream.ClientManager.add_client(self(), state)
    {:ok, state}
  end

  def websocket_handle(frame, state) do
    Logger.debug(fn -> "Client sent message #{inspect frame}" end)
    Instruments.increment("certstream.websocket_msg_in", 1, tags: ["ip:#{state[:ip_address]}"])
    {:ok, state}
  end

  def websocket_info({:mail, box_pid, serialized_certificates, _message_count, message_drop_count}, state) do
    if message_drop_count > 0 do
      Instruments.increment("certstream.dropped_messages", message_drop_count, tags: ["ip:#{state[:ip_address]}"])
      Logger.warn("Message drop count greater than 0 -> #{message_drop_count}")
    end

    Logger.debug(fn -> "Sending client #{length(serialized_certificates |> List.flatten)} client frames" end)

    # Reactive our pobox active mode
    :pobox.active(box_pid, fn(msg, _) -> {{:ok, msg}, :nostate} end, :nostate)

    response = serialized_certificates
                 |> Enum.map(fn message ->
                    message
                    |> Enum.map(&({:text, &1}))
                 end)
                 |> List.flatten

    {
      :reply,
      response,
      state
    }
  end

  defp routes do
    [
      {"/", __MODULE__, []},
      {@full_stream_url, __MODULE__, []},
      {@domains_only_url, __MODULE__, []},
      {"/example.json", __MODULE__, [:example_json]},
      {"/latest.json", __MODULE__, [:latest_json]},
      {"/static/[...]", :cowboy_static, {:dir, "frontend/dist/static/"}},
      {"/#{System.get_env(~s(STATS_URL)) || 'stats'}", __MODULE__, [:stats]}
    ]
  end

  def start_link(_opts) do
    Logger.info("Starting web server on port #{get_port()}...")
    case System.get_env("SSL_ENABLED") do
      nil ->
        :cowboy.start_clear(
          :websocket_server,
          [{:port, get_port()}],
          %{
            :env => %{
              :dispatch => :cowboy_router.compile([
                {:_, routes()}
              ])
            },
          }
        )
      _ -> :cowboy.start_tls(
          :websocket_server,
          [
            port: get_port(),
            keyfile: System.get_env("SSL_KEY"),
            certfile: System.get_env("SSL_CERT")
          ],
          %{
            :env => %{
              :dispatch => :cowboy_router.compile([
                {:_, routes()}
              ])
            },
          }
        )
    end

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
