defmodule WaifuVaultTest do
  use ExUnit.Case
  require WaifuVault

  describe "create_bucket/0" do
    test "happy path" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, %{"token" => "server token"})
      end)

      bucket = WaifuVault.create_bucket()

      refute is_nil(bucket)
      refute is_nil(bucket["token"])
      assert bucket["token"] == "server token"
    end
  end
end
