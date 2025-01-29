defmodule WaifuVaultTest do
  use ExUnit.Case
  require WaifuVault

  describe "create_bucket/0" do
    test "happy path" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, %{"token" => "server token"})
      end)

      {:ok, bucketResponse} = WaifuVault.create_bucket()

      refute is_nil(bucketResponse)
      assert bucketResponse.token == "server token"
      assert bucketResponse.files == []
      assert bucketResponse.albums == []
    end
  end

  # Way too slow due to 3 1-second retries
  describe "slow error cases" do
    test "timeout" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      {:error, error} = WaifuVault.create_bucket()

      assert error == :timeout
    end

    test "internal server error" do
      Req.Test.stub(WaifuVault, fn conn ->
        Plug.Conn.send_resp(conn, 500, "internal server error")
      end)

      {:error, error} = WaifuVault.create_bucket()

      assert error == "Error 500 (500): {response.body}"
    end
  end
end
