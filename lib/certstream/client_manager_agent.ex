require Logger

defmodule Certstream.ClientManager do
  @moduledoc """
  An agent responsible for managing and broadcasting to websocket clients. Uses :pobox to
  provide buffering and eventually drops messages if the backpressure isn't enough.
  """
  use Agent

  @full_stream_url Application.fetch_env!(:certstream, :full_stream_url)
  @domains_only_url Application.fetch_env!(:certstream, :domains_only_url)

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
        |> Enum.map(fn {k, v} ->
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

    serialized_certificates_full = certificates
                                     |> Enum.map(&Jason.encode!/1)

    certificates_lite = certificates
                          |> Enum.map(&remove_chain_from_cert/1)
                          |> Enum.map(&remove_der_from_cert/1)

    Certstream.CertifcateBuffer.add_certs_to_buffer(certificates_lite)

    serialized_certificates_lite = certificates_lite
                                     |> Enum.map(&Jason.encode!/1)

    dns_entries_only = certificates
                         |> Enum.map(&get_in(&1, [:data, :leaf_cert, :all_domains]))
                         |> Enum.map(fn dns_entries -> %{:message_type => "dns_entries", :data => dns_entries} end)
                         |> Enum.map(&Jason.encode!/1)

    get_clients()
      |> Enum.each(fn {_, client_state} ->
        case client_state.path do
          @full_stream_url ->         send_bundle(serialized_certificates_full, client_state.po_box)
          @full_stream_url <> "/" ->  send_bundle(serialized_certificates_full, client_state.po_box)
          @domains_only_url ->        send_bundle(dns_entries_only, client_state.po_box)
          @domains_only_url <> "/" -> send_bundle(dns_entries_only, client_state.po_box)
          _ ->                        send_bundle(serialized_certificates_lite, client_state.po_box)
        end
      end)
  end

  def send_bundle(entries, po_box) do
    :pobox.post(po_box, entries)
  end

  def remove_chain_from_cert(cert) do
    cert
      |> pop_in([:data, :chain])
      |> elem(1)
  end

  def remove_der_from_cert(cert) do
    # Clean the der field from the leaf cert
    cert
      |> pop_in([:data, :leaf_cert, :as_der])
      |> elem(1)
  end
end
