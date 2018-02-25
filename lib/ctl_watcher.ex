require IEx
require Logger

defmodule Certstream.Watcher do
  @bad_ctl_servers [
    "alpha.ctlogs.org/",
    "clicky.ct.letsencrypt.org/",
    "ct.akamai.com/",
    "ct.filippo.io/behindthesofa/",
    "ct.gdca.com.cn/",
    "ct.izenpe.com/",
    "ct.izenpe.eus/",
    "ct.sheca.com/",
    "ct.startssl.com/",
    "ct.wosign.com/",
    "ctserver.cnnic.cn/",
    "ctlog.api.venafi.com/",
    "ctlog.gdca.com.cn/",
    "ctlog.sheca.com/",
    "ctlog.wosign.com/",
    "ctlog2.wosign.com/",
    "flimsy.ct.nordu.net:8080/",
    "log.certly.io/",
    "nessie2021.ct.digicert.com/log/",
    "plausible.ct.nordu.net/",
    "www.certificatetransparency.cn/ct/",
  ]

  def start do
    {:ok, ctl_processor_pid} = Certstream.CTLProcessor.start_link()
    fetch_all_logs()
      |> Enum.map(fn log ->
           Certstream.Worker.start_link(log, ctl_processor_pid)
         end)
  end

  def fetch_all_logs do
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

end
