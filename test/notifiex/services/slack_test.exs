defmodule Notifiex.Service.SlackTest do
  use ExUnit.Case, async: false

  alias Notifiex.Service.Slack

  setup do
    bypass = Bypass.open()
    base = "http://localhost:#{bypass.port}"

    Application.put_env(:notifiex, :slack_post_message_url, base <> "/chat.postMessage")
    Application.put_env(:notifiex, :slack_files_upload_url, base <> "/files.upload")

    on_exit(fn ->
      Application.delete_env(:notifiex, :slack_post_message_url)
      Application.delete_env(:notifiex, :slack_files_upload_url)
    end)

    {:ok, bypass: bypass}
  end

  describe "call/2 — chat.postMessage" do
    test "posts JSON body with bearer token header", %{bypass: bypass} do
      parent = self()

      Bypass.expect_once(bypass, "POST", "/chat.postMessage", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        auth = Plug.Conn.get_req_header(conn, "authorization")
        content_type = Plug.Conn.get_req_header(conn, "content-type")

        send(parent, {:request, body, auth, content_type})

        Plug.Conn.resp(conn, 200, ~s({"ok": true}))
      end)

      Slack.call(
        %{text: "hello", channel: "general"},
        %{token: "xoxb-secret"}
      )

      assert_receive {:request, body, auth, [content_type]}
      assert auth == ["Bearer xoxb-secret"]
      assert content_type =~ ~r{^application/json}

      decoded = Jason.decode!(body)
      assert decoded == %{"text" => "hello", "channel" => "general"}
    end

    test "returns nil when no files (preserves current behaviour)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/chat.postMessage", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true}))
      end)

      result =
        Slack.call(
          %{text: "hi", channel: "general"},
          %{token: "xoxb-secret"}
        )

      assert is_nil(result)
    end
  end

  describe "call/2 — files.upload" do
    @tag :tmp_dir
    test "uploads each file as multipart and returns list of results", %{
      bypass: bypass,
      tmp_dir: tmp
    } do
      file_a = Path.join(tmp, "a.txt")
      file_b = Path.join(tmp, "b.txt")
      File.write!(file_a, "alpha")
      File.write!(file_b, "beta")

      parent = self()

      Bypass.expect(bypass, "POST", "/chat.postMessage", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true}))
      end)

      Bypass.expect(bypass, "POST", "/files.upload", fn conn ->
        opts = [parsers: [:multipart], length: 10_000_000]
        conn = Plug.Parsers.call(conn, Plug.Parsers.init(opts))
        auth = Plug.Conn.get_req_header(conn, "authorization")

        send(parent, {:upload, conn.body_params, auth})

        Plug.Conn.resp(conn, 200, ~s({"ok": true, "file": {}}))
      end)

      result =
        Slack.call(
          %{text: "with files", channel: "general"},
          %{
            token: "xoxb-secret",
            files: [file_a, file_b],
            channel_ids: "C123,C456"
          }
        )

      assert is_list(result)
      assert length(result) == 2

      # Both uploads should have hit /files.upload with the same channels value and bearer token
      assert_receive {:upload, params1, ["Bearer xoxb-secret"]}
      assert_receive {:upload, params2, ["Bearer xoxb-secret"]}

      for params <- [params1, params2] do
        assert params["channels"] == "C123,C456"
        assert %Plug.Upload{} = params["file"]
      end
    end

    test "does not hit files.upload for empty / whitespace-only entries", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/chat.postMessage", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"ok": true}))
      end)

      Bypass.stub(bypass, "POST", "/files.upload", fn conn ->
        flunk("files.upload should not be hit for empty entries")
        Plug.Conn.resp(conn, 500, "")
      end)

      # The for-comprehension still yields nil for skipped entries,
      # so the result list has the same length as `files`.
      result =
        Slack.call(
          %{text: "no files", channel: "general"},
          %{token: "xoxb-secret", files: ["", "   "], channel_ids: "C123"}
        )

      assert result == [nil, nil]
    end
  end

  describe "error paths" do
    test "non-2xx response from chat.postMessage is silently dropped (current behaviour)",
         %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/chat.postMessage", fn conn ->
        Plug.Conn.resp(conn, 401, ~s({"ok": false, "error": "invalid_auth"}))
      end)

      # call/2 returns the result of the if/files block, NOT send_message.
      # So an error from chat.postMessage is invisible to the caller — that's
      # pre-existing behaviour we want to preserve through the swap.
      assert is_nil(Slack.call(%{text: "x", channel: "general"}, %{token: "bad"}))
    end

    @tag :tmp_dir
    test "transport failure surfaces from files.upload as error tuple", %{
      bypass: bypass,
      tmp_dir: tmp
    } do
      file = Path.join(tmp, "f.txt")
      File.write!(file, "x")

      Bypass.down(bypass)

      # post message will fail transport-side too but its result is dropped;
      # the for-comprehension over files surfaces the transport error tuple.
      result =
        Slack.call(
          %{text: "x", channel: "general"},
          %{token: "t", files: [file], channel_ids: "C123"}
        )

      assert [{:error, {:error, _reason}}] = result
    end
  end
end
