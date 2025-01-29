defmodule WaifuVault do
  @moduledoc """
  Documentation for `WaifuVault`.
  """

  @request_options (Mix.env == :test) && Req.new(
    base_url: "https://waifuvault.moe/rest",
    plug: {Req.Test, WaifuVault}
  ) || Req.new(
    base_url: "https://waifuvault.moe/rest"
  )


  @doc """
  Tells the server to create a bucket. duh.
  """
  def create_bucket() do
    {:ok, response} = Req.get(@request_options, url: "/bucket/create")

    response.body
  end
end
