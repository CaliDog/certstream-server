require IEx
require Logger
require DateTime

defmodule Certstream.CTLProcessor do
  use GenServer

  @log_entry_types %{0 => :X509LogEntryType, 1 => :PrecertLogEntryType}

  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(args) do
    {:ok, args}
  end

  def handle_call({:ctl_update, operator, ids, ctl_update}, _from, state) do
    ctl_update["entries"]
      |> Enum.zip(ids)
      |> Enum.map(fn {entry, cert_index} ->
          parsed_entry = parse_entry(entry)
          parsed_entry
            |> Map.merge(
                 %{
                   :cert_index => cert_index,
                   :seen => :os.system_time(:microsecond) / 1_000_000,
                   :source => %{
                     :url => operator["url"],
                     :name => operator["description"],
                   },
                   :cert_link => "http://#{operator["url"]}/ct/v1/get-entries?start=#{cert_index}&end=#{cert_index}"
                 }
               )
         end)
      |> push_update_to_clients

    {:reply, :ok, state}
  end

  def push_update_to_clients(entries) do
    IO.puts("Parsed #{length(entries)} entries...")
    :ok
  end

  def parse_entry(entry) do
    leaf_input = Base.decode64!(entry["leaf_input"])
    extra_data = Base.decode64!(entry["extra_data"])

    <<
      _version :: integer,
      _leaf_type :: integer,
      _timestamp :: size(64),
      type :: size(16),
      entry :: binary
    >> = leaf_input

    entry_type = @log_entry_types[type]

    cert = %{:update_type => entry_type}

    [top | rest] = [
      parse_leaf_entry(entry_type, entry),
      parse_extra_data(entry_type, extra_data)
    ] |> List.flatten

    cert
      |> Map.put(:leaf_cert, top)
      |> Map.put(:chain, rest)

  end

  defp parse_extra_data(:X509LogEntryType, extra_data) do
    <<_chain_length :: size(24), chain::binary>> = extra_data
    parse_certificate_chain(chain, [])
  end

  defp parse_extra_data(:PrecertLogEntryType, extra_data) do
    <<
      length :: size(24),
      certificate_data :: binary - size(length),
      _chain_length :: size(24),
      extra_chain :: binary
    >> = extra_data

    [Certstream.CertificateParser.parse(certificate_data), parse_certificate_chain(extra_chain, [])]

  end

  defp parse_certificate_chain(<<size :: size(24), cert_chunk :: binary - size(size), rest :: binary>>, entries) do
    parse_certificate_chain(rest, [Certstream.CertificateParser.parse(cert_chunk) | entries])
  end

  defp parse_certificate_chain(<<>>, entries) do
    entries |> Enum.reverse()
  end

  defp parse_leaf_entry(:X509LogEntryType,
         <<length :: size(24),
           certificate_data :: binary - size(length),
           _extensions :: size(16)>>)
    do

    Certstream.CertificateParser.parse(certificate_data)

  end

  defp parse_leaf_entry(:PrecertLogEntryType, _entry) do [] end  # For now we don't parse these and rely on everything in "extra_data" only
end