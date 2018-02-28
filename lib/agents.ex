require Logger

defmodule Certstream.CertifcateBuffer do
  use Agent

  @doc """
    An agent designed to effectively ring-buffer certificate updates as they come in so
    the most recent 25 certificates can be aggregated in a json-based API.

    Basically, this is what feeds both the `/example.json` and `latest.json` endpoints.
  """

  def run() do
    Agent.start(fn -> [] end, name: __MODULE__)
  end

  @doc "Adds a certificate update to the circular certificate buffer"
  def add_certs_to_buffer(certificates) do
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

  @doc "Gets the latest certificate seen by Certstream, indented with 4 spaces"
  def get_example_json do
    Agent.get(__MODULE__,
      fn certificates ->
        certificates
          |> List.first
          |> Poison.encode!(pretty: true, indent: 4)
      end
    )
  end

  @doc "Gets the latest 25 cetficiates seen by Certstream, indented with 4 spaces"
  def get_latest_json do
    Agent.get(__MODULE__,
      fn certificates ->
        %{}
          |> Map.put(:messages, certificates)
          |> Poison.encode!(pretty: true, indent: 4)
      end
    )
  end
end

defmodule Certstream.ClientManager do
  use Agent

  def run() do
    Agent.start(fn -> %{} end, name: __MODULE__)
  end

  def add_client(client_pid, client_state) do
    {:ok, box_pid} = :pobox.start_link(client_pid, 250, :queue)

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
      state
        |> Map.delete(client_pid)
    end)
  end

  def get_clients do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def broadcast_to_clients(entries) do
    Logger.debug("Broadcasting #{length(entries)} certificates to clients")

    certificates = entries
      |> Enum.map(&(%{:message_type => "certificate_update", :data => &1}))

    Certstream.CertifcateBuffer.add_certs_to_buffer(certificates)

    serialized_certificates = certificates |> Enum.map(&Poison.encode!/1)

    get_clients()
      |> Enum.map(fn {_, v} -> Map.get(v, :po_box) end)
      |> Enum.each(fn boxpid ->
        :pobox.post(boxpid, serialized_certificates )
      end)
  end
end