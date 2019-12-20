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
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        ctl_log_info = Jason.decode!(response.body)

        ctl_log_info
          |> Map.get("logs")
          # Replace the operator IDs with a hashmap of id/name
          |> Enum.map(&(replace_operator(&1, ctl_log_info["operators"])))
          # Filter out any blacklisted CTLs
          |> Enum.filter(&(!Enum.member?(@bad_ctl_servers, &1["url"])))

      {:ok, response} ->
        Logger.error("Unexpected status code #{response.status_code} fetching url https://www.gstatic.com/ct/log_list/all_logs_list.json! Sleeping for a bit and trying again...")
        :timer.sleep(:timer.seconds(10))
        fetch_all_logs()

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

    schedule_update()

    {:ok, state}
  end

  def handle_info({:ssl_closed, _}, state) do
    Logger.info("Worker #{inspect self()} got :ssl_closed message. Ignoring.")
    {:noreply, state}
  end


  def handle_info(:update, state) do
    Logger.debug(fn -> "Worker #{inspect self()} got tick." end)

    state = case state[:tree_size] do
      nil ->
        Logger.info("Worker #{inspect self()} initializing tree size.")
        Map.put(state, :tree_size, fetch_tree_size(state))
      _ ->
        state
    end

    current_size = fetch_tree_size(state)

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

  defp fetch_update(state, start, end_) do
    Logger.info("GETing https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}")

    case HTTPoison.get("https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}", [], [timeout: 10_000, recv_timeout: 10_000]) do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        response.body
          |> Jason.decode!

      {:ok, response} ->
        Logger.error("Unexpected status code #{response.status_code} fetching url https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}! Sleeping for a bit and trying again...")
        :timer.sleep(10_000)
        fetch_update(state, start, end_)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error: #{reason}! Sleeping for 10 seconds and trying again...")
        :timer.sleep(:timer.seconds(10))
        fetch_update(state, start, end_)
    end
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
