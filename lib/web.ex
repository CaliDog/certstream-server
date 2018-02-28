require Logger

defmodule Certstream.APIServer do

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

  def init(req, [:example_json] = state) do
    res = :cowboy_req.reply(
      200,
      %{'content_type' => 'application/json'},
      Certstream.CertifcateBuffer.get_example_json(),
      req
    )
    {:ok, res, state}
  end

  def init(req, [:latest_json] = state) do
    res = :cowboy_req.reply(
      200,
      %{'content_type' => 'application/json'},
      Certstream.CertifcateBuffer.get_latest_json(),
      req
    )
    {:ok, res, state}
  end

  def serve_root(req, state) do
    res = :cowboy_req.reply(200, %{'content_type' => 'text/html'}, @certstream_html, req)
    {:ok, res, state}
  end

end

defmodule Certstream.WebsocketServer do
  @moduledoc false

  def init(req, state) do
    # If we have a websocket request, do the thing, otherwise just host our main HTML
    if is_websocket_req(req) do
      Logger.info("New client connected #{inspect req.peer}")
      {
        :cowboy_websocket,
        req,
        %{:headers => req.headers, :qs => req.qs, :peer => req.peer},
        %{:idle_timeout => 12 * 60 * 60 * 1000, :compress => true}
      }
    else
      Certstream.APIServer.serve_root(req, state)
    end
  end

  def terminate(_reason, partial_req, _state) do
    if is_websocket_req(partial_req) do
      Logger.info("Client disconnected #{inspect self()}")
      Certstream.ClientManager.remove_client(self())
    end
    :ok
  end

  defp is_websocket_req(req) do
    Map.has_key?(req.headers, "upgrade")
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
      Logger.warn("Message drop count > 0 -> #{message_drop_count}")
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

  def start() do
    Certstream.ClientManager.run()
    Certstream.CertifcateBuffer.run()

    {:ok, _pid} = :cowboy.start_clear(
      :websocket_server,
      [{:port, 4000}],
      %{
        :env => %{
          :dispatch => :cowboy_router.compile([
            { :_,
              [
                {"/", Certstream.WebsocketServer, []},
                {"/example.json", Certstream.APIServer, [:example_json]},
                {"/latest.json", Certstream.APIServer, [:latest_json]}
              ]}
          ])
        },
      }
    )
  end

end
