defmodule WaifuVaultTest do
  @moduledoc """
  Test the WaifuVault module, stubbing all HTTP requests.

    To print out the tests in order: `mix test --trace --seed 0`
    To include the slow tests: `mix test --include slow`
    To run *only* slow tests: `mix test --only slow`

  Note that although the functions include examples, we cannot use
  `doctest WaifuVault` since our tests need Req.Test stubs to work.
  """
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

  describe "unexpected error responses: " do
    test "JSON response body is missing any message/status/name fields" do
      Req.Test.stub(WaifuVault, fn conn ->
        Plug.Conn.send_resp(
          conn,
          678,
          Jason.encode_to_iodata!(%{
            "status" => "789",
            "another unexpected field" => "yo!"
          })
        )
      end)

      {:error, wierdness} = WaifuVault.delete_bucket("incorrect-token")
      assert Regex.match?(~r/^Error .+ \(678\): 678$/, wierdness)
    end
  end

  # These test work but are very slow due to multiple retries
  # NOTE: the :slow tag must be on each one you want to exclude
  describe "slow error cases: " do
    @tag :slow
    test "timeout" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      {:error, error} = WaifuVault.create_bucket()

      assert error =~ "Unexpected Error"
      assert error =~ ":timeout"
    end

    @tag :slow
    test "internal server error" do
      Req.Test.stub(WaifuVault, fn conn ->
        Plug.Conn.send_resp(conn, 500, "internal server error")
      end)

      {:error, error} = WaifuVault.create_bucket()

      assert error == "Error internal server error (500): 500"
    end
  end
end
