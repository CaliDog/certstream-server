require Logger

defmodule Certstream.WebsocketServer do
  use GenServer

  @certstream_html """
  <!DOCTYPE html>
  <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <link href="https://fonts.googleapis.com/css?family=Open+Sans:400,700" rel="stylesheet">
    </head>
    <body>
      <div id="app"></div>
    <script type="text/javascript" src="https://storage.googleapis.com/certstream-prod/build.js?v=#{Mix.Project.config[:version]}"></script></body>
  </html>
  """

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

  # / handler
  def init(req, state) do
    # If we have a websocket request, do the thing, otherwise just host our main HTML
    if Map.has_key?(req.headers, "upgrade") do
      Logger.info("New client connected #{inspect req.peer}")
      {
        :cowboy_websocket,
        req,
        %{:is_websocket => true, :connect_time => DateTime.utc_now},
        %{:idle_timeout => 12 * 60 * 60 * 1000, :compress => true}
      }
    else
      res = :cowboy_req.reply(
        200,
        %{'content_type' => 'text/html'},
        @certstream_html,
        req
      )
      {:ok, res, state}
    end
  end

  def terminate(_reason, _partial_req, state) do
    if state[:is_websocket] do
      Logger.info("Client disconnected #{inspect self()}")
      Certstream.ClientManager.remove_client(self())
    end
  end

  def websocket_init(state) do
    Certstream.ClientManager.add_client(self(), state)
    {:ok, state}
  end

  def websocket_handle(frame, state) do
    Logger.info("Client sent message #{inspect frame}")
    {:ok, state}
  end

  def websocket_info({:mail, box_pid, payload, _message_count, message_drop_count}, state) do
    if message_drop_count > 0 do
      Logger.warn("Message drop count greater than 0 -> #{message_drop_count}")
    end

    Logger.debug("Sending client #{length(payload |> List.flatten)} client frames")

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
            { :_,
              [
                {"/", __MODULE__, []},
                {"/example.json", __MODULE__, [:example_json]},
                {"/latest.json", __MODULE__, [:latest_json]}
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
