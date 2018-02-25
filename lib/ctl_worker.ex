require Logger
require IEx

defmodule Certstream.Worker do
  use GenServer

  defp get_tree_size(state) do
    case HTTPoison.get("https://#{state[:url]}ct/v1/get-sth", [], [timeout: 60_000, recv_timeout: 60_000]) do
      {:ok, response} ->
        response.body
        |> Poison.Parser.parse!
        |> Map.get("tree_size")

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error fetching url https://#{state[:url]}ct/v1/get-sth: #{reason}! Sleeping for a bit and trying again...")
        :timer.sleep(10_000)
        get_tree_size(state)
    end
  end

  def start_link(operator, processor) do
    GenServer.start_link(
      __MODULE__,
      %{
        :operator => operator,
        :url => operator["url"],
        :processor => processor
      })
  end

  def init(state) do
    Logger.info("Worker #{inspect self()} started with url #{state[:url]}.")

    state = Map.put(state, :tree_size, get_tree_size(state))

    schedule_update()

    {:ok, state}
  end

  def handle_info(:update, state) do
    Logger.debug("Worker #{inspect self()} got tick.")

    current_size = get_tree_size(state)

    Logger.debug("Tree size #{current_size} - #{state[:tree_size]}")

    if current_size > state[:tree_size] do
      Logger.info("Worker #{inspect self()} with url #{state[:url]} found #{current_size - state[:tree_size]} certificates [#{state[:tree_size]} -> #{current_size}].")
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

  defp broadcast_updates(state, current_size) do
    certificate_count = (current_size - state[:tree_size])
    certificates = Enum.to_list (current_size - certificate_count)..current_size - 1

    certificates
      |> Enum.chunk_every(64)
      |> Enum.each(
           fn ids ->
             GenServer.call(
               state[:processor],
               {
                 :ctl_update,
                 state.operator,
                 ids,
                 fetch_update(state, List.first(ids), List.last(ids))
               },
               :infinity
             )
           end)

    Map.put(state, :tree_size, current_size)
  end

  defp schedule_update do
    Process.send_after(self(), :update, 15 * 1000) # In 15 seconds
  end
end