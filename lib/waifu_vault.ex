defmodule WaifuVault do
  @moduledoc """
  Documentation for `WaifuVault`.
  """

  @request_options (Mix.env() == :test &&
                      Req.new(
                        base_url: "https://waifuvault.moe/rest",
                        plug: {Req.Test, WaifuVault}
                      )) || Req.new(base_url: "https://waifuvault.moe/rest")

  @doc """
  Buckets are virtual collections that are linked to your IP and a token. When you create a bucket, you will receive a bucket token that you can use in Get Bucket to get all the files in that bucket

  NOTE: Only one bucket is allowed per client IP address, if you call it more than once, it will return the same bucket token

  To create a bucket, use the create_bucket function. This function does not take any arguments.

  ```
  require WaifuVault
  bucket = WaifuVault.create_bucket()
  print(bucket.token)
  ```
  """
  def create_bucket() do
    case Req.get(@request_options, url: "/bucket/create") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, bucket_response_from_map(body)}

      {:ok, response} ->
        {:error, "Error #{response.status} (#{response.status}): {response.body}"}

      {:error, error} ->
        {:error, error.reason}
    end
  end

  def bucket_response_from_map(map) do
    %{
      token: map["token"],
      files: Enum.map(map["files"] || [], &file_response_from_map/1),
      albums: Enum.map(map["albums"] || [], &album_response_from_map/1)
    }
  end

  def file_response_from_map(map) do
    %{
      token: map["token"],
      url: map["url"],
      retentionPeriod: map["retentionPeriod"],
      bucket: map["bucket"],
      views: map["views"],
      album: album_response_from_map(map["album"] || %{}),
      options: file_options_from_map(map["options"] || %{})
    }
  end

  def album_response_from_map(map) do
    %{
      files: Enum.map(map["files"] || [], &file_response_from_map/1),
      token: map["token"],
      bucketToken: map["bucketToken"],
      publicToken: map["publicToken"],
      name: map["name"]
    }
  end

  def file_options_from_map(map) do
    %{
      hideFilename: map["hideFilename"] || false,
      oneTimeDownload: map["oneTimeDownload"] || false,
      protected: map["oneTimeDownload"] || false
    }
  end
end
