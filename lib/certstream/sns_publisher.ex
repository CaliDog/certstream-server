defmodule Certstream.SNSPublisher do
  @moduledoc """
  Publishes certificate updates to AWS SNS for async consumption.
  Each certificate is published as a separate SNS message.
  """
  require Logger

  def publish_certificates(certificates_json_list) when is_list(certificates_json_list) do
    Task.start(fn ->
      Enum.each(certificates_json_list, &publish_single_certificate/1)
    end)
    :ok
  end

  defp publish_single_certificate(certificate_json) when is_binary(certificate_json) do
    topic_arn = Application.get_env(:certstream, :sns_topic_arn)
    
    # For now, just log the SNS publish
    # TODO: Implement actual SNS publishing via AWS CLI or Lambda
    Logger.info("Publishing certificate to SNS topic: #{topic_arn}")
    Logger.debug("Certificate data: #{String.slice(certificate_json, 0, 100)}...")
  end
end