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
    
    case publish_to_sns(certificate_json, topic_arn) do
      {:ok, %{body: body, status_code: 200}} ->
        Logger.debug("Published certificate to SNS")
      {:error, reason} ->
        Logger.error("Failed to publish to SNS: #{inspect(reason)}")
    end
  end

  defp publish_to_sns(message, topic_arn) do
    ExAws.SNS.publish(message, topic_arn: topic_arn)
    |> ExAws.request()
  end
end