require Logger

defmodule Certstream.CertifcateBuffer do
  use Agent

  @moduledoc """
    An agent designed to ring-buffer certificate updates as they come in so the most recent 25 certificates can be
    aggregated for the /example.json and /latest.json routes.
  """

  @doc "Starts the CertificateBuffer agent and creates an ETS table for tracking the certificates processed"
  def start_link(_opts) do
    Logger.info("Starting #{__MODULE__}...")
    Agent.start_link(
      fn ->
        :ets.new(:counter, [:named_table, :public])
        :ets.insert(:counter, processed_certificates: 0)
        []
      end,
      name: __MODULE__
    )
  end

  @doc "Adds a certificate update to the circular certificate buffer"
  def add_certs_to_buffer(certificates) do
    count = :ets.update_counter(:counter, :processed_certificates, length(certificates))

    # Every 10,000 certs let us know.
    count - length(certificates)..count
      |> Enum.each(fn c ->
        if rem(c, 10_000) == 0 do
          IO.puts "Processed #{c |> Number.Delimit.number_to_delimited([precision: 0])} certificates..."
        end
      end)

    certificates |> Enum.each(fn cert ->
      Agent.update(__MODULE__, fn state ->
        state = [cert | state]
        case length(state) do
          26 -> state |> List.delete_at(-1)
          _ -> state
        end
      end)
    end)
  end

  @doc "The number of certificates processed, in human-readable/formatted string output"
  def get_processed_certificates do
    :ets.lookup(:counter, :processed_certificates)
      |> Keyword.get(:processed_certificates)
      |> Number.Delimit.number_to_delimited([precision: 0])
  end

  @doc "Gets the latest certificate seen by Certstream, indented with 4 spaces"
  def get_example_json do
    Agent.get(__MODULE__,
      fn certificates ->
        certificates
          |> List.first
          |> Jason.encode!()
      end
    )
  end

  @doc "Gets the latest 25 cetficiates seen by Certstream, indented with 4 spaces"
  def get_latest_json do
    Agent.get(__MODULE__,
      fn certificates ->
        %{}
          |> Map.put(:messages, certificates)
          |> Jason.encode!()
      end
    )
  end
end

defmodule Certstream.ClientManager do
  use Agent

  def start_link(_opts) do
    Logger.info("Starting #{__MODULE__}...")
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def add_client(client_pid, client_state) do
    {:ok, box_pid} = :pobox.start_link(client_pid, 500, :queue)

    :pobox.active(box_pid, fn(msg, _) -> {{:ok, msg}, :nostate} end, :nostate)

    Agent.update(
      __MODULE__,
      &Map.put(
        &1,
        client_pid,
        client_state |> Map.put(:po_box, box_pid)
      )
    )
  end

  def remove_client(client_pid) do
    Agent.update(__MODULE__, fn state ->
      # Remove our pobox
      state |> Map.get(client_pid) |> Map.get(:po_box) |> Process.exit(:kill)

      # Remove client from state map
      state |> Map.delete(client_pid)
    end)
  end

  def get_clients do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def get_client_count do
    Agent.get(__MODULE__, fn state -> state |> Map.keys |> length end)
  end

  def get_clients_json do
    Agent.get(__MODULE__, fn state ->

      state
        |> Enum.map(fn {k,v} ->

          coerced_payload = v
                            |> Map.update!(:connect_time, &DateTime.to_iso8601/1)
                            |> Map.drop([:po_box, :is_websocket])
          {inspect(k), coerced_payload}
        end)
        |> Enum.into(%{})
    end)
  end

  def broadcast_to_clients(entries) do
    Logger.debug("Broadcasting #{length(entries)} certificates to clients")

    certificates = entries
      |> Enum.map(&(%{:message_type => "certificate_update", :data => &1}))

    Certstream.CertifcateBuffer.add_certs_to_buffer(certificates)

    serialized_certificates = certificates |> Enum.reduce([], fn (cert, acc) ->
      try do
        [Jason.encode!(cert) | acc]
      rescue
        e in _ ->
          Logger.error(
"""
Parsing cert failed - #{inspect e}
#{inspect cert[:data][:cert_link]}
#{inspect cert[:data][:leaf_cert][:as_der]}
"""
          )
          acc
      end
    end)

    get_clients()
      |> Enum.map(fn {_, v} -> Map.get(v, :po_box) end)
      |> Enum.each(fn boxpid ->
        :pobox.post(boxpid, serialized_certificates)
      end)
  end
end