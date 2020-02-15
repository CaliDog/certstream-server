require Logger

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
    Logger.debug(fn -> "Broadcasting #{length(entries)} certificates to clients" end)

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
