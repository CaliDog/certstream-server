require IEx
require Logger

defmodule Certstream.CT.Watcher do
  use GenServer

  @bad_ctl_servers [
    "alpha.ctlogs.org/", "clicky.ct.letsencrypt.org/", "ct.akamai.com/", "ct.filippo.io/behindthesofa/",
    "ct.gdca.com.cn/", "ct.izenpe.com/", "ct.izenpe.eus/", "ct.sheca.com/", "ct.startssl.com/", "ct.wosign.com/",
    "ctserver.cnnic.cn/", "ctlog.api.venafi.com/", "ctlog.gdca.com.cn/", "ctlog.sheca.com/", "ctlog.wosign.com/",
    "ctlog2.wosign.com/", "flimsy.ct.nordu.net:8080/", "log.certly.io/", "nessie2021.ct.digicert.com/log/",
    "plausible.ct.nordu.net/", "www.certificatetransparency.cn/ct/",
  ]

  def run do
    Certstream.WebsocketServer.start
    fetch_all_logs()
      |> Enum.map(fn log ->
          GenServer.start_link(
            __MODULE__,
            %{
              :operator => log,
              :url => log["url"],
            })
         end)
  end

  defp fetch_all_logs do
    case HTTPoison.get("https://www.gstatic.com/ct/log_list/all_logs_list.json") do
      {:ok, response} ->
        ctl_log_info = Poison.Parser.parse!(response.body)

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

    if current_size > state[:tree_size] do
      Logger.debug("Worker #{inspect self()} with url #{state[:url]} found #{current_size - state[:tree_size]} certificates [#{state[:tree_size]} -> #{current_size}].")
      broadcast_updates(state, current_size)
    end

    schedule_update()

    {:noreply, state}
  end

  defp fetch_update(state, start, end_) do
    Logger.debug("GETing https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}")

    case HTTPoison.get("https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}", [], [timeout: 60_000, recv_timeout: 60_000]) do
      {:ok, response} ->
        response
          |> Map.get(:body)
          |> Poison.Parser.parse!

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error fetching url https://#{state[:url]}ct/v1/get-entries?start=#{start}&end=#{end_}: #{reason}!")
        :timer.sleep(10_000)
        fetch_update(state, start, end_)
    end
  end

  defp fetch_tree_size(state) do
    case HTTPoison.get("https://#{state[:url]}ct/v1/get-sth", [], [timeout: 60_000, recv_timeout: 60_000]) do
      {:ok, response} ->
        response.body
        |> Poison.Parser.parse!
        |> Map.get("tree_size")

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

             update["entries"]
               |> Enum.zip(ids)
               |> Enum.map(fn {entry, cert_index} ->
                 parsed_entry = Certstream.CT.Parser.parse_entry(entry)
                 parsed_entry
                   |> Map.merge(
                        %{
                          :cert_index => cert_index,
                          :seen => :os.system_time(:microsecond) / 1_000_000,
                          :source => %{
                            :url => state[:operator]["url"],
                            :name => state[:operator]["description"],
                          },
                          :cert_link => "http://#{state[:operator]["url"]}/ct/v1/get-entries?start=#{cert_index}&end=#{cert_index}"
                        }
                      )
                 end)
               |> Certstream.ClientManager.broadcast_to_clients
           end)

    Map.put(state, :tree_size, current_size)
  end

  defp schedule_update do
    Process.send_after(self(), :update, 15 * 1000) # In 15 seconds
  end

end
