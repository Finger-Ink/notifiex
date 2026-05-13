defmodule Notifiex.Service.Slack do
  @moduledoc """
  Slack service for Notifiex.
  """

  @behaviour Notifiex.ServiceBehaviour

  @default_post_message_url "https://slack.com/api/chat.postMessage"
  @default_files_upload_url "https://slack.com/api/files.upload"

  @doc """
  Sends a message to the specified channel.

  `payload` should include the following:
  * `text`: The message text. (required)
  * `channel`: The channel to send the message to. (required)

  `options` should include the following:
  * `token`: Authentication token. (required)
  """
  @spec call(map, map) :: {:ok, binary} | {:error, {atom, any}}
  def call(payload, options) when is_map(payload) and is_map(options) do
    token = Map.get(options, :token)

    # send message (without file)
    send_message(payload, post_message_url(), token)

    # fetch channels and files
    channels = Map.get(options, :channel_ids)
    files = Map.get(options, :files)

    # Send each file through the files.upload API
    maybe_upload_files(files, channels, token)
  end

  defp maybe_upload_files(nil, _channels, _token), do: nil

  defp maybe_upload_files(files, channels, token) do
    for file <- files do
      if String.trim(file) != "" do
        send_files(file, channels, token)
      end
    end
  end

  defp post_message_url do
    Application.get_env(:notifiex, :slack_post_message_url, @default_post_message_url)
  end

  defp files_upload_url do
    Application.get_env(:notifiex, :slack_files_upload_url, @default_files_upload_url)
  end

  @spec send_message(map, binary, binary) :: {:ok, binary} | {:error, {atom, any}}
  defp send_message(_payload, nil, nil), do: {:error, {:missing_options, nil}}

  defp send_message(payload, url, token) do
    case Req.post(url,
           json: payload,
           auth: {:bearer, token},
           decode_body: false
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, {:error_response, body}}

      {:error, exception} ->
        {:error, {:error, Exception.message(exception)}}
    end
  end

  @spec send_files(binary, binary, binary) :: {:ok, binary} | {:error, {atom, any}}
  defp send_files(_files, nil, nil), do: {:error, {:missing_options, nil}}

  defp send_files(file, channels, token) do
    case Req.post(files_upload_url(),
           form_multipart: [
             file: File.stream!(file),
             channels: channels
           ],
           auth: {:bearer, token},
           decode_body: false
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, {:error_response, body}}

      {:error, exception} ->
        {:error, {:error, Exception.message(exception)}}
    end
  end
end
