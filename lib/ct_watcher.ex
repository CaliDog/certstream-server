require Logger

defmodule Certstream.CTWatcher do
  @moduledoc """
  The GenServer responsible for watching a specific CT server. It ticks every 15 seconds via
  `schedule_update`, and uses Process.send_after to trigger new requests to see if there are
  any certificates to fetch and broadcast.
  """
  use GenServer
  use Instruments

  @bad_ctl_servers [
    "ct.ws.symantec.com/", "vega.ws.symantec.com/", "deneb.ws.symantec.com/", "sirius.ws.symantec.com/",
    "log.certly.io/", "ct.izenpe.com/", "ct.izenpe.eus/", "ct.wosign.com/", "ctlog.wosign.com/", "ctlog2.wosign.com/",
    "ct.gdca.com.cn/", "ctlog.api.venafi.com/", "ctserver.cnnic.cn/", "ct.startssl.com/",
    "www.certificatetransparency.cn/ct/", "flimsy.ct.nordu.net:8080/", "ctlog.sheca.com/",
    "log.gdca.com.cn/", "log2.gdca.com.cn/", "ct.sheca.com/", "ct.akamai.com/", "alpha.ctlogs.org/",
    "clicky.ct.letsencrypt.org/", "ct.filippo.io/behindthesofa/", "ctlog.gdca.com.cn/", "plausible.ct.nordu.net/",
    "dodo.ct.comodo.com/"
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
    # Schedule the initial update to happen between 0 and 3 seconds from now in
    # order to stagger when we hit these servers and avoid a thundering herd sort
    # of issue upstream
    delay = :rand.uniform(30) / 10

    Logger.info("Worker #{inspect self()} started with url #{state[:url]} and initial start time of #{delay} seconds from now.")

    schedule_update(delay)

    {:ok, state}
  end

  def http_request_with_retries(full_url, options \\ [timeout: 10_000, recv_timeout: 10_000]) do
    # Go ask for the first 1024 entries
    Logger.info("Sending GET request to #{full_url}")

    user_agent = {"User-Agent", user_agent()}

    case HTTPoison.get(full_url, [user_agent], options) do
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

    # On first run attempt to fetch 1024 certificates, and see what the API returns. However
    # many certs come back is what we should use as the batch size moving forward (at least
    # in theory).
    state = case Map.has_key?(state, :batch_size) do
              true -> state
              false ->
                batch_size = "https://#{state[:url]}ct/v1/get-entries?start=0&end=1024"
                             |> http_request_with_retries
                             |> Map.get("entries")
                             |> Enum.count

                Logger.info("Worker #{inspect self()} found batch size of #{batch_size}.")

                Map.put(state, :batch_size, batch_size)
            end

    current_tree_size = "https://#{state[:url]}ct/v1/get-sth"
                     |> http_request_with_retries
                     |> Map.get("tree_size")

    # On first run populate the state[:tree_size] key
    state = case Map.has_key?(state, :tree_size) do
      true -> state
      false ->
        Logger.info("Worker #{inspect self()} initializing tree size.")
        Map.put(state, :tree_size, current_tree_size)
    end

    Logger.debug(fn -> "Tree size #{current_tree_size} - #{state[:tree_size]}" end)

    state = case current_tree_size > state[:tree_size] do
      true ->
        Logger.info("Worker #{inspect self()} with url #{state[:url]} found #{current_tree_size - state[:tree_size]} certificates [#{state[:tree_size]} -> #{current_tree_size}].")

        cert_count = current_tree_size - state[:tree_size]
        Instruments.increment("certstream.worker.#{state[:url]}", cert_count)
        Instruments.increment("certstream.aggregate_owners.#{state[:operator]["operated_by"]["name"]}", cert_count)

        broadcast_updates(state, current_tree_size)

        state
          |> Map.put(:tree_size, current_tree_size)
          |> Map.update(:processed_count, 0, &(&1 + (current_tree_size - state[:tree_size])))
      false -> state
    end

    schedule_update()

    {:noreply, state}
  end

  defp broadcast_updates(state, current_size) do
    certificate_count = (current_size - state[:tree_size])
    certificates = Enum.to_list (current_size - certificate_count)..current_size - 1

    Logger.info("Certificate count - #{certificate_count} ")
    certificates
      |> Enum.chunk_every(state[:batch_size])
      # Use Task.async_stream to have 5 concurrent requests to the CT server to fetch
      # our certificates without waiting on the previous chunk.
      |> Task.async_stream(&(fetch_and_broadcast_certs(&1, state)), max_concurrency: 5, timeout: :timer.seconds(600))
      |> Enum.to_list # Nop to just pull the requests through async_stream
  end

  def fetch_and_broadcast_certs(ids, state) do
    Logger.debug(fn -> "Attempting to retrieve #{ids |> Enum.count} entries" end)
    entries = "https://#{state[:url]}ct/v1/get-entries?start=#{List.first(ids)}&end=#{List.last(ids)}"
                |> http_request_with_retries
                |> Map.get("entries", [])

    entries
      |> Enum.zip(ids)
      |> Enum.map(fn {entry, cert_index} ->
        entry
          |> Certstream.CTParser.parse_entry
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
      Logger.debug(fn ->
        "We didn't retrieve all the entries for this batch, fetching missing #{batch_count - entry_count} entries"
      end)
      fetch_and_broadcast_certs(ids |> Enum.drop(Enum.count(entries)), state)
    end
  end

  defp schedule_update(seconds \\ 10) do # Default to 10 second ticks
    # Note, we need to use Kernel.trunc() here to guarentee this is an integer
    # because :timer.seconds returns an integer or a float depending on the
    # type put in, :erlang.send_after seems to hang with floats for some
    # reason :(
    Process.send_after(self(), :update, trunc(:timer.seconds(seconds)))
  end

  # Allow the user agent to be overridden in the config, or use a default Certstream identifier
  defp user_agent do
    case Application.fetch_env!(:certstream, :user_agent) do
      :default -> "Certstream Server v#{Application.spec(:certstream, :vsn)}"
      user_agent_override -> user_agent_override
    end
  end
end
