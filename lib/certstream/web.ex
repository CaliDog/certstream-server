require Logger

defmodule Certstream.WebsocketServer do
  @moduledoc """
  Simple web server with health check endpoint for monitoring.
  """
  use GenServer

  # GenServer callback
  def init(args) do {:ok, args} end

  # /health handler - returns simple health check response
  def init(req, [:health]) do
    processed_certs = Certstream.CertifcateBuffer.get_processed_certificates
    
    health_response = %{
      status: "healthy",
      processed_certificates: processed_certs,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    } |> Jason.encode!()
    
    res = :cowboy_req.reply(
      200,
      %{'content-type' => 'application/json'},
      health_response,
      req
    )
    {:ok, res, %{}}
  end

  # Default handler for all other routes - return 404
  def init(req, _state) do
    res = :cowboy_req.reply(
      404,
      %{'content-type' => 'text/plain'},
      "Not Found",
      req
    )
    {:ok, res, %{}}
  end

  def start_link(_opts) do
    Logger.info("Starting web server on port #{get_port()}...")
    :cowboy.start_clear(
      :health_server,
      [{:port, get_port()}],
      %{
        :env => %{
          :dispatch => :cowboy_router.compile([
            {:_,
              [
                {"/health", __MODULE__, [:health]},
                {"/:...", __MODULE__, []}  # Catch-all for 404
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
