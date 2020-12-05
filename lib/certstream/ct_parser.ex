defmodule Certstream.CTParser do
  @moduledoc false

  @log_entry_types %{
    0 => :X509LogEntry,
    1 => :PrecertLogEntry
  }

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

  defp parse_extra_data(:X509LogEntry, extra_data) do
    <<_chain_length :: size(24), chain::binary>> = extra_data
    parse_certificate_chain(chain, [])
  end

  defp parse_extra_data(:PrecertLogEntry, extra_data) do
    <<
      length :: size(24),
      certificate_data :: binary - size(length),
      _chain_length :: size(24),
      extra_chain :: binary
    >> = extra_data

    [
      parse_certificate(certificate_data, :leaf),
      parse_certificate_chain(extra_chain, [])
    ]

  end

  defp parse_certificate(certificate_data, type) do
    case type do
      :leaf -> EasySSL.parse_der(certificate_data, serialize: true, all_domains: true)
      :chain -> EasySSL.parse_der(certificate_data, serialize: true)
    end

  end

  defp parse_certificate_chain(<<size :: size(24), certificate_data :: binary - size(size), rest :: binary>>, entries) do
    parse_certificate_chain(rest, [parse_certificate(certificate_data, :chain) | entries])
  end

  defp parse_certificate_chain(<<>>, entries) do
    entries |> Enum.reverse()
  end

  defp parse_leaf_entry(:X509LogEntry,
         <<length :: size(24),
           certificate_data :: binary - size(length),
           _extensions :: size(16)>>)
    do

    parse_certificate(certificate_data, :leaf)
  end

  defp parse_leaf_entry(:PrecertLogEntry, _entry) do [] end  # For now we don't parse these and rely on everything in "extra_data" only

end
