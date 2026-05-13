defmodule Notifiex.Service.Discord do
  @moduledoc """
  Discord service for Notifiex.
  """

  @behaviour Notifiex.ServiceBehaviour

  @doc """
  Sends a message through Webhooks.

  `payload` should include the following:
  * `content`: Message content (up to 2000 characters). (required)

  `options` should include the following:
  * `webhook`: Webhook URI. (required)
  """
  @spec call(map, map) :: {:ok, binary} | {:error, {atom, any}}
  def call(payload, options) when is_map(payload) and is_map(options) do
    webhook = Map.get(options, :webhook)

    send_discord(payload, webhook)
  end

  @spec send_discord(map, binary) :: {:ok, binary} | {:error, {atom, any}}
  defp send_discord(_payload, nil), do: {:error, {:missing_options, nil}}

  defp send_discord(payload, url) do
    case Req.post(url, json: payload, decode_body: false) do
      {:ok, %Req.Response{status: 204, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, {:error_response, body}}

      {:error, exception} ->
        {:error, {:error, Exception.message(exception)}}
    end
  end
end
