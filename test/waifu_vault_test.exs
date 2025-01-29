defmodule WaifuVaultTest do
  use ExUnit.Case
  require WaifuVault

  describe "create_bucket/0" do
    test "bucket is created" do
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

  describe "delete_bucket/1" do
    test "bucket is destroyed" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, "true")
      end)

      {:ok, true} = WaifuVault.delete_bucket("valid-token")
    end

    test "incorrect bucket token" do
      Req.Test.stub(WaifuVault, fn conn ->
        #        json = Jason.enc
        Plug.Conn.send_resp(
          conn,
          400,
          Jason.encode_to_iodata!(%{
            "status" => "400",
            "name" => "BAD_REQUEST",
            "message" => "Unable to delete bucket with token incorrect-token"
          })
        )
      end)

      {:error, "Error 400 (BAD_REQUEST): Unable to delete bucket with token incorrect-token"} =
        WaifuVault.delete_bucket("incorrect-token")
    end
  end

  # Way too slow due to multiple retries
  describe "slow error cases" do
    #    test "timeout" do
    #      Req.Test.stub(WaifuVault, fn conn ->
    #        Req.Test.transport_error(conn, :timeout)
    #      end)
    #
    #      {:error, error} = WaifuVault.create_bucket()
    #
    #      assert error == :timeout
    #    end
    #
    #    test "internal server error" do
    #      Req.Test.stub(WaifuVault, fn conn ->
    #        Plug.Conn.send_resp(conn, 500, "internal server error")
    #      end)
    #
    #      {:error, error} = WaifuVault.create_bucket()
    #
    #      assert error == "Error 500 (500): {response.body}"
    #    end
  end
end
