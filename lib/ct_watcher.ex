require Logger

defmodule Certstream.CTWatcher do
  use GenServer

  @bad_ctl_servers [
    "alpha.ctlogs.org/", "clicky.ct.letsencrypt.org/", "ct.akamai.com/", "ct.filippo.io/behindthesofa/",
    "ct.gdca.com.cn/", "ct.izenpe.com/", "ct.izenpe.eus/", "ct.sheca.com/", "ct.startssl.com/", "ct.wosign.com/",
    "ctserver.cnnic.cn/", "ctlog.api.venafi.com/", "ctlog.gdca.com.cn/", "ctlog.sheca.com/", "ctlog.wosign.com/",
    "ctlog2.wosign.com/", "flimsy.ct.nordu.net:8080/", "log.certly.io/", "nessie2021.ct.digicert.com/log/",
    "plausible.ct.nordu.net/", "www.certificatetransparency.cn/ct/", "ct.googleapis.com/testtube/",
    "ct.googleapis.com/daedalus/"
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
    fetch_all_logs()
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

  defp fetch_all_logs do
    case HTTPoison.get("https://www.gstatic.com/ct/log_list/all_logs_list.json") do
      {:ok, response} ->
        ctl_log_info = Jason.decode!(response.body)

        ctl_log_info
          |> Map.get("logs")
          # Replace the operator IDs with a hashmap of id/name
          |> Enum.map(&(replace_operator(&1, ctl_log_info["operators"])))
          # Filter out any blacklisted CTLs
          |> Enum.filter(&(!Enum.member?(@bad_ctl_servers, &1["url"])))

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error: #{reason}! Sleeping for 10 seconds and trying again...")
        :timer.sleep(:timer.seconds(10))
        fetch_all_logs()
    end
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

    state = Map.put(state, :tree_size, fetch_tree_size(state))

    schedule_update()

    {:ok, state}
  end

  def handle_info(:update, state) do
    Logger.debug("Worker #{inspect self()} got tick.")

    current_size = fetch_tree_size(state)

    Logger.debug("Tree size #{current_size} - #{state[:tree_size]}")

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

  defp fetch_update(state, start, end_) do
    Logger.info("GETing https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}")

    case HTTPoison.get("https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}", [], [timeout: 60_000, recv_timeout: 60_000]) do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        response.body
          |> Jason.decode!

      {:ok, response} ->
        Logger.error("Unexpected status code #{response.status_code} fetching url https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}, sleeping and trying again!")
        :timer.sleep(10_000)
        fetch_update(state, start, end_)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error fetching url https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}: #{reason}!")
        :timer.sleep(10_000)
        fetch_update(state, start, end_)
    end
  end

  defp fetch_tree_size(state) do
    case HTTPoison.get("https://#{state[:url]}ct/v1/get-sth", [], [timeout: 60_000, recv_timeout: 60_000]) do
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

    certificates
      |> Enum.chunk_every(64)
      |> Enum.each(
           fn ids ->
             update = fetch_update(state, List.first(ids), List.last(ids))

             update
               |> Map.get("entries", [])
               |> Enum.zip(ids)
               |> Enum.map(fn {entry, cert_index} ->
                 parsed_entry = Certstream.CTParser.parse_entry(entry)
                 parsed_entry
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
           end)
  end

  defp schedule_update do
    Process.send_after(self(), :update, :timer.seconds(15)) # In 15 seconds
  end

end
