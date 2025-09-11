require Logger

defmodule Certstream.ClientManager do
  @moduledoc """
  Processes certificates from CT logs and publishes them to AWS SNS.
  Maintains certificate serialization and buffering logic.
  """
  use GenServer

  def start_link(_opts) do
    Logger.info("Starting #{__MODULE__}...")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    {:ok, %{}}
  end

  def broadcast_to_clients(entries) do
    Logger.debug(fn -> "Processing #{length(entries)} certificates" end)

    certificates = entries
                     |> Enum.map(&(%{:message_type => "certificate_update", :data => &1}))

    certificates_lite = certificates
                          |> Enum.map(&remove_chain_from_cert/1)
                          |> Enum.map(&remove_der_from_cert/1)

    # Update certificate buffer for health check metrics
    Certstream.CertifcateBuffer.add_certs_to_buffer(certificates_lite)

    # Serialize and publish to SNS
    serialized_certificates_lite = certificates_lite
                                     |> Enum.map(&Jason.encode!/1)

    Certstream.SNSPublisher.publish_certificates(serialized_certificates_lite)
  end

  def remove_chain_from_cert(cert) do
    cert
      |> pop_in([:data, :chain])
      |> elem(1)
  end

  def remove_der_from_cert(cert) do
    # Clean the der field from the leaf cert
    cert
      |> pop_in([:data, :leaf_cert, :as_der])
      |> elem(1)
  end
end
