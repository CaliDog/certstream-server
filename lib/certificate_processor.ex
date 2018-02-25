require Record
require Logger
require IEx

defmodule Certstream.CertificateParser do
  @moduledoc false

  @pubkey_schema Record.extract_all(from_lib: "public_key/include/OTP-PUB-KEY.hrl")

  @extended_key_usages %{
    {1,3,6,1,5,5,7,3,1} => "TLS Web server authentication",
    {1,3,6,1,5,5,7,3,2} => "TLS Web client authentication",
    {1,3,6,1,5,5,7,3,3} => "Code signing",
    {1,3,6,1,5,5,7,3,4} => "E-mail protection",
    {1,3,6,1,5,5,7,3,8} => "Timestamping",
    {1,3,6,1,5,5,7,3,9} => "OCSPstamping",
    {1,3,6,1,5,5,7,3,5} => "IP security end system",
    {1,3,6,1,5,5,7,3,6} => "IP security tunnel termination",
    {1,3,6,1,5,5,7,3,7} => "IP security user",
  }

  @authority_info_access_oids %{
    {1,3,6,1,5,5,7,48,1} => "OCSP - URI",
    {1,3,6,1,5,5,7,48,2} => "CA Issuers - URI",
  }

  def parse(certificate_der) do
    cert = :public_key.pkix_decode_cert(certificate_der, :otp) |> get_field(:tbsCertificate)

    %{}
      |> Map.put(:as_der, Base.encode64(certificate_der))
      |> Map.put(:serial_number, cert |> get_field(:serialNumber) |> Integer.to_string(16))
      |> Map.put(:fingerprint, certificate_der |> fingerprint_cert)
      |> Map.put(:subject, cert |> parse_subject)
      |> Map.put(:extensions, cert |> parse_extensions)
      |> Map.merge(parse_expiry(cert))

  end

  def get_field(record, field) do
    record_type = elem(record, 0)
    idx = @pubkey_schema[record_type]
          |> Keyword.keys
          |> Enum.find_index(&(&1 == field))

    elem(record, idx + 1)
  end

  def fingerprint_cert(certificate) do
    :crypto.hash(:sha, certificate)
      |> Base.encode16
      |> String.to_charlist
      |> Enum.chunk(2)
      |> Enum.join(":")
  end

  def parse_expiry(cert) do
    {:Validity, {:utcTime, not_before }, {:utcTime, not_after}} = cert |> get_field(:validity)

    %{:not_before => not_before |> asn1_to_epoch, :not_after => not_after |> asn1_to_epoch}
  end

  def asn1_to_epoch(asn1_time) do
    date = case asn1_time |> Enum.chunk_every(2) do
      [year, month, day, hour, minute, second, 'Z'] -> ['20' ++ year, month, day, hour, minute, second]
      [year, month, day, hour, minute, 'Z'] -> ['20' ++ year, month, day, hour, minute, '00']
      _ ->
        IEx.pry
        raise("Unhandled ASN1 time structure")
    end

    date_args = date |> Enum.map(&(to_string(&1) |> String.to_integer))

    case apply(NaiveDateTime, :new, date_args) do
      {:ok, datetime} -> datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix
      _ ->
        IEx.pry
        raise("Unhandled ASN1 time structure")
    end
  end

  def parse_subject(cert) do
    subject = %{
      :CN => nil,
      :C => nil,
      :L => nil,
      :ST => nil,
      :O => nil,
      :OU => nil,
    }

    {:rdnSequence, subject_attribute} = cert |> get_field(:subject)

    subject = subject_attribute |> List.flatten |> Enum.reduce(subject, fn attr, subject ->
      {:AttributeTypeAndValue, oid, attribute_value} = attr

      attr_atom = case oid do
        {2, 5, 4, 3} -> :CN
        {2, 5, 4, 6} -> :C
        {2, 5, 4, 7} -> :L
        {2, 5, 4, 8} -> :ST
        {2, 5, 4, 10} -> :O
        {2, 5, 4, 11} -> :OU
        _ -> nil
      end

      case attr_atom do
        nil -> subject
        _ -> %{subject | attr_atom => attribute_value |> coerce_to_string |> to_string}
      end
    end)

    Map.put(subject, :aggregated, subject |> aggregate_subject)

  end

  def coerce_to_string(attribute_value) do
    case attribute_value do
      {:printableString, string} -> string
      {:utf8String, string} -> string
      {:teletexString, string} -> string
      string when is_list(string) -> string
      _ ->
        IEx.pry
        raise("Unhandled subject attribute type #{inspect attribute_value}")
    end
  end

  def aggregate_subject(subject) do
    subject
      # Filter out empty values
      |> Enum.filter(fn {_, v} -> v != nil end)
      # Turn everything in to a string so C=blah.com
      |> Enum.map(fn {k, v} -> (k |> to_string) <> "=" <> (v |> to_string) end)
      # Add a buffer to the front to
      |> Enum.join("/")
      |> String.replace_prefix("", "/")
  end

  def parse_extensions(cert) do
    extensions = cert |> get_field(:extensions)

    case extensions do
      :asn1_NOVALUE -> %{}
      _ ->
        extensions
        |> Enum.reduce(%{}, fn extension, extension_map ->
          case extension do
            {:Extension, {1, 3, 6, 1, 5, 5, 7, 1, 1}, _critical, authority_info_access} ->
              Map.put(
                extension_map,
                :authorityInfoAccess,
                authority_info_access
                |> Enum.reduce([], fn match, entries ->
                  {:AccessDescription, oid, {:uniformResourceIdentifier, url}} = match
                  ["#{@authority_info_access_oids[oid]}:#{url}" | entries]
                end)
                |> Enum.join("\n")
                |> String.replace_suffix("", "\n")
              )

            {:Extension, {1, 3, 6, 1, 4, 1, 11129, 2, 4, 2}, _critical, sct_data} ->
              Map.put(
                extension_map,
                :ctlSignedCertificateTimestamp,
                Base.url_encode64(sct_data)
              )

            {:Extension, {1, 3, 6, 1, 4, 1, 11129, 2, 4, 3}, _critical, _null_data} ->
              Map.put(
                extension_map,
                :ctlPoisonByte,
                true
              )

            {:Extension, {2, 5, 29, 14}, _critical, subject_key_identifier} ->
              Map.put(
                extension_map,
                :subjectKeyIdentifier,
                subject_key_identifier
                |> Base.encode16
                |> String.to_charlist
                |> Enum.chunk(2)
                |> Enum.join(":")
              )

            {:Extension, {2, 5, 29, 15}, _critical, key_usage} ->
              Map.put(
                extension_map,
                :keyUsage,
                key_usage
                  |> join_usage_types
              )

            {:Extension, {2, 5, 29, 17}, _critical, san_entries} ->
              Map.put(
                extension_map,
                :subjectAltName,
                san_entries
                |> Enum.reduce([], fn entry, san_list ->
                  case entry do
                    {:dNSName, dns_name} -> ["DNS:" <> (dns_name |> to_string) | san_list]
                    {:uniformResourceIdentifier, identifier} -> ["URI:" <> (identifier |> to_string) | san_list]
                    {:rfc822Name, identifier} -> ["RFC 822Name:" <> (identifier |> to_string) | san_list]
                    {:directoryName, _sequence} -> san_list

                    _ ->
                      IEx.pry
                      raise("Unhandled SAN entry type #{inspect entry}")
                  end
                end)
                |> Enum.join(", ")
              )

            {:Extension, {2, 5, 29, 18}, _critical, issuer_alt_name_entries} ->
              Map.put(
                extension_map,
                :issuerAltName,
                issuer_alt_name_entries
                |> Enum.reduce([], fn entry, issuer_list ->
                  case entry do
                    {:uniformResourceIdentifier, identifier} -> ["URI:" <> (identifier |> to_string) | issuer_list]
                    {:dNSName, dns_name} -> ["DNS:" <> (dns_name |> to_string) | issuer_list]
                    _ ->
                      IEx.pry
                      raise("Unhandled IAN entry type #{inspect entry}")
                  end
                end)
                |> Enum.join(", ")
              )

            {:Extension, {2, 5, 29, 19}, _critical, {:BasicConstraints, is_ca, _max_pathlen}} ->
              Map.put(
                extension_map,
                :basicConstraints,
                case is_ca do
                  true -> "CA:TRUE"
                  false -> "CA:FALSE"
                end
              )

            {:Extension, {2, 5, 29, 31}, _critical, crl_distribution_points} ->
              Map.put(
                extension_map,
                :crlDistributionPoints,
                crl_distribution_points
                  |> Enum.reduce([], fn distro_point, output ->
                       case distro_point do
                         {:DistributionPoint, {:fullName, crls}, :asn1_NOVALUE, :asn1_NOVALUE} ->
                           crl_string = crls
                            |> Enum.map(fn identifier ->
                                 case identifier do
                                   {:uniformResourceIdentifier, uri} ->
                                     " URI:#{uri}"
                                 end
                               end)
                            |> Enum.join("\n")

                           output = ["Full Name:" | output]
                           output = [crl_string | output]
                           output
                            |> Enum.reverse()

                         _ ->
                           IEx.pry
                           raise("Unhandled CRL distrobution point #{inspect distro_point}")
                       end
                     end)
                  |> Enum.join("\n")
              )

            {:Extension, {2, 5, 29, 32}, _critical, policy_entries} ->
              Map.put(
                extension_map,
                :certificatePolicies,
                policy_entries
                  |> List.flatten
                  |> Enum.reduce([], fn entry, policy_entries ->
                    case entry do
                      {:PolicyInformation, oid, :asn1_NOVALUE} ->
                        ["Policy: #{oid |> Tuple.to_list |> Enum.join(".")}" | policy_entries]

                      {:PolicyInformation, oid, policy_information} ->
                        oid_string = oid
                                       |> Tuple.to_list
                                       |> Enum.join(".")
                                       |> String.replace_prefix("", "Policy: ")

                        message = [oid_string]

                        policy_information
                          |> Enum.reduce(message, fn policy, message ->
                              case policy do
                                {:PolicyQualifierInfo, {1, 3, 6, 1, 5, 5, 7, 2, 1}, cps_data} ->
                                  cps_string = cps_data
                                                 |> to_charlist
                                                 |> Enum.drop(2)
                                                 |> to_string
                                                 |> String.replace_prefix("", "  CPS: ")
                                  [cps_string | message]

                                {:PolicyQualifierInfo, {1, 3, 6, 1, 5, 5, 7, 2, 2}, user_notice_data} ->
                                  <<_::binary-size(6), user_notice::binary>> = user_notice_data
                                  [user_notice |> String.replace_prefix("", "  User Notice: ") | message]

                              end
                            end)
                          |> Enum.reverse
                      _ -> IEx.pry
                    end
                  end)
                  |> Enum.join("\n")
              )

            {:Extension, {2, 5, 29, 35}, _critical, {:AuthorityKeyIdentifier, authority_key_identifier, _, _}} ->
              case authority_key_identifier do
                value when is_binary(value) ->
                  Map.put(
                    extension_map,
                    :authorityKeyIdentifier,
                    authority_key_identifier
                    |> Base.encode16
                    |> String.to_charlist
                    |> Enum.chunk(2)
                    |> Enum.join(":")
                    |> String.replace_prefix("", "keyid:")
                    |> String.replace_suffix("", "\n")
                  )
                :asn1_NOVALUE -> extension_map

                _ -> IEx.pry
              end

            {:Extension, {2, 5, 29, 37}, _critical, extended_key_usage} ->
              Map.put(
                extension_map,
                :extendedKeyUsage,
                extended_key_usage
                  |> Enum.map(&(@extended_key_usages[&1]))
                  |> Enum.join(", ")
              )

            {:Extension, oid, _critical, _payload} ->
              Map.put_new(extension_map, :extra, [])
              |> Map.update!(:extra, fn x ->
                   [oid |> Tuple.to_list |> Enum.join(".") | x]
                 end)
          end
      end)
    end
  end

  def join_usage_types(key_usage) do
    key_usage
      |> Enum.reduce([], fn usage_atom, output ->
        [usage_atom |> camel_to_spaces | output]
      end)
      |> Enum.reverse
      |> Enum.join(", ")
  end

  def camel_to_spaces(atom) do
    atom
      |> Atom.to_charlist
      |> Enum.reduce([], fn char, charlist ->
           charlist = [char | charlist]
           case char in 65..90 do
             true -> List.insert_at(charlist, 1, ' ')
             false -> charlist
           end
         end)
      |> Enum.reverse
      |> to_string
      |> String.split
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")
  end

end
