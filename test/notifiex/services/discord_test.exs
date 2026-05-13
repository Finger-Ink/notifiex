defmodule Notifiex.Service.DiscordTest do
  use ExUnit.Case, async: false

  alias Notifiex.Service.Discord

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass, webhook: "http://localhost:#{bypass.port}/webhooks/123/abc"}
  end

  test "returns {:ok, body} on 204 No Content", %{bypass: bypass, webhook: webhook} do
    parent = self()

    Bypass.expect_once(bypass, "POST", "/webhooks/123/abc", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      content_type = Plug.Conn.get_req_header(conn, "content-type")
      send(parent, {:request, body, content_type})

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, ""} = Discord.call(%{content: "hi"}, %{webhook: webhook})

    assert_receive {:request, body, [content_type]}
    assert content_type =~ ~r{^application/json}
    assert Jason.decode!(body) == %{"content" => "hi"}
  end

  test "returns {:error, {:error_response, body}} on non-204 status", %{
    bypass: bypass,
    webhook: webhook
  } do
    Bypass.expect_once(bypass, "POST", "/webhooks/123/abc", fn conn ->
      Plug.Conn.resp(conn, 400, ~s({"message": "Cannot send empty message", "code": 50006}))
    end)

    assert {:error, {:error_response, body}} =
             Discord.call(%{content: ""}, %{webhook: webhook})

    assert body =~ "Cannot send empty message"
  end

  test "returns {:error, {:missing_options, nil}} when webhook is missing" do
    assert Discord.call(%{content: "hi"}, %{}) == {:error, {:missing_options, nil}}
  end

  test "returns {:error, {:error, reason}} on transport failure", %{
    bypass: bypass,
    webhook: webhook
  } do
    Bypass.down(bypass)

    assert {:error, {:error, _reason}} = Discord.call(%{content: "hi"}, %{webhook: webhook})
  end
end
