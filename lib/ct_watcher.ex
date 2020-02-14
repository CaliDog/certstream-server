require Logger

defmodule Certstream.CTWatcher do
  use GenServer

  @bad_ctl_servers [
    "ct.ws.symantec.com/", "vega.ws.symantec.com/", "deneb.ws.symantec.com/", "sirius.ws.symantec.com/",
    "log.certly.io/", "ct.izenpe.com/", "ct.izenpe.eus/", "ct.wosign.com/", "ctlog.wosign.com/", "ctlog2.wosign.com/",
    "ct.gdca.com.cn/", "ctlog.api.venafi.com/", "ctserver.cnnic.cn/", "ct.startssl.com/",
    "www.certificatetransparency.cn/ct/", "flimsy.ct.nordu.net:8080/", "ctlog.sheca.com/",
    "log.gdca.com.cn/", "log2.gdca.com.cn/", "ct.sheca.com/", "ct.akamai.com/", "alpha.ctlogs.org/",
    "clicky.ct.letsencrypt.org/", "ct.filippo.io/behindthesofa/", "ctlog.gdca.com.cn/", "plausible.ct.nordu.net/"
  ]

  def child_spec(log) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [log]},
      restart: :permanent,
    }
  end

  def start_and_link_watchers(name: supervisor_name) do
    Logger.info("Initializing CT Watchers...")
    # Fetch all CT lists
    ctl_log_info = http_request_with_retries("https://www.gstatic.com/ct/log_list/all_logs_list.json")

    ctl_log_info
      |> Map.get("logs")
      # Replace the operator IDs with a hashmap of id/name
      |> Enum.map(fn entry ->
           replace_operator(entry, ctl_log_info["operators"])
         end)
      # Filter out any blacklisted CTLs
      |> Enum.filter(&(!Enum.member?(@bad_ctl_servers, &1["url"])))
      |> Enum.each(fn log ->
           DynamicSupervisor.start_child(supervisor_name, child_spec(log))
         end)
  end

  def start_link(log) do
    GenServer.start_link(
      __MODULE__,
      %{:operator => log, :url => log["url"]}
    )
  end

  defp replace_operator(log, operators) do
    Map.replace!(log,
      "operated_by",
      Enum.find(
        operators,
        fn operator ->
          log["operated_by"]
            |> List.first == operator["id"]
        end
      )
    )
  end

  def init(state) do
    Logger.info("Worker #{inspect self()} started with url #{state[:url]}.")

    # Attempt to fetch 1024 certificates, and see what the API returns. However
    # many certs come back is what we should use as the batch size moving forward
    # (at least in theory).
    batch_size = http_request_with_retries("https://#{state[:url]}ct/v1/get-entries?start=0&end=1024")
                   |> Map.get("entries")
                   |> Enum.count

    Logger.info("Worker #{inspect self()} found batch size of #{batch_size}.")

    state = state
              |> Map.put(:batch_size, batch_size)

    schedule_update()

    {:ok, state}
  end

  def http_request_with_retries(full_url, options \\ [timeout: 10_000, recv_timeout: 10_000]) do
    # Go ask for the first 1024 entries
    Logger.info("Sending GET request to #{full_url}")
    case HTTPoison.get(full_url, [], options) do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        response.body
          |> Jason.decode!

      {:ok, response} ->
        Logger.error("Unexpected status code #{response.status_code} fetching url #{full_url}! Sleeping for a bit and trying again...")
        :timer.sleep(:timer.seconds(10))
        http_request_with_retries(full_url, options)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error: #{reason}! Sleeping for 10 seconds and trying again...")
        :timer.sleep(:timer.seconds(10))
        http_request_with_retries(full_url, options)
    end
  end

  def handle_info({:ssl_closed, _}, state) do
    Logger.info("Worker #{inspect self()} got :ssl_closed message. Ignoring.")
    {:noreply, state}
  end

  def handle_info(:update, state) do
    Logger.debug(fn -> "Worker #{inspect self()} got tick." end)

    current_size = fetch_tree_size(state)

    state = case state[:tree_size] do
      nil ->
        Logger.info("Worker #{inspect self()} initializing tree size.")
        Map.put(state, :tree_size, current_size)
      _ ->
        state
    end

    Logger.debug(fn -> "Tree size #{current_size} - #{state[:tree_size]}" end)

    state = case current_size > state[:tree_size] do
      true ->
        Logger.info("Worker #{inspect self()} with url #{state[:url]} found #{current_size - state[:tree_size]} certificates [#{state[:tree_size]} -> #{current_size}].")
        broadcast_updates(state, current_size)
        state
          |> Map.put(:tree_size, current_size)
          |> Map.update(:processed_count, 0, &(&1 + (current_size - state[:tree_size])))
      false -> state
    end

    schedule_update()

    {:noreply, state}
  end

  defp fetch_tree_size(state) do
    case HTTPoison.get("https://#{state[:url]}ct/v1/get-sth", [], [timeout: 10_000, recv_timeout: 10_000]) do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        response.body
          |> Jason.decode!
          |> Map.get("tree_size")

      {:ok, response} ->
        Logger.error("Unexpected status code #{response.status_code} fetching url https://#{state[:url]}ct/v1/get-sth:! Sleeping for a bit and trying again...")
        :timer.sleep(10_000)
        fetch_tree_size(state)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error fetching url https://#{state[:url]}ct/v1/get-sth: #{reason}! Sleeping for a bit and trying again...")
        :timer.sleep(10_000)
        fetch_tree_size(state)
    end
  end

  defp broadcast_updates(state, current_size) do
    certificate_count = (current_size - state[:tree_size])
    certificates = Enum.to_list (current_size - certificate_count)..current_size - 1

    Logger.info("Certificate count - #{certificate_count} ")
    certificates
      |> Enum.chunk_every(state[:batch_size])
      |> Enum.each(&(fetch_and_broadcast_certs(&1, state)))
  end

  def fetch_and_broadcast_certs(ids, state) do
    Logger.debug("Attempting to retrieve #{ids |> Enum.count} entries")
    entries = http_request_with_retries("https://#{state[:url]}ct/v1/get-entries?start=#{List.first(ids)}&end=#{List.last(ids)}")
                |> Map.get("entries", [])

    entries
      |> Enum.zip(ids)
      |> Enum.map(fn {entry, cert_index} ->
        Certstream.CTParser.parse_entry(entry)
          |> Map.merge(
               %{
                 :cert_index => cert_index,
                 :seen => :os.system_time(:microsecond) / 1_000_000,
                 :source => %{
                   :url => state[:operator]["url"],
                   :name => state[:operator]["description"],
                 },
                 :cert_link => "http://#{state[:operator]["url"]}ct/v1/get-entries?start=#{cert_index}&end=#{cert_index}"
               }
             )
      end)
      |> Certstream.ClientManager.broadcast_to_clients

    entry_count = Enum.count(entries)
    batch_count = Enum.count(ids)

    # If we have *unequal* counts the API has returned less certificates than our initial batch
    # heuristic. Drop the entires we retrieved and recurse to fetch others.
    if entry_count != batch_count do
      Logger.info("We didn't retrieve all the entries for this batch, fetching missing #{batch_count - entry_count} entries")
      fetch_and_broadcast_certs(ids |> Enum.drop(entry_count), state)
    end
  end

  defp schedule_update do
    Process.send_after(self(), :update, :timer.seconds(15)) # In 15 seconds
  end

end
