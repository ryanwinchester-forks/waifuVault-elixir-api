defmodule WaifuVault do
  @moduledoc """
  Documentation for `WaifuVault`.

  ```
  require WaifuVault
  ```
  """

  # Ensure tests don't hit the real server by using Req.Test to intercept all HTTP calls
  # (note that there is *probably* a better way to do this)
  @request_options (Mix.env() == :test &&
                      Req.new(
                        base_url: "https://example.com/rest",
                        plug: {Req.Test, WaifuVault}
                      )) || Req.new(base_url: "https://waifuvault.moe/rest")

  @doc """
  Buckets are virtual collections that are linked to your IP and a token. When you create a bucket, you will receive a bucket token that you can use in Get Bucket to get all the files in that bucket

  NOTE: Only one bucket is allowed per client IP address, if you call it more than once, it will return the same bucket token

  To create a bucket, use the create_bucket function. This function does not take any arguments.

  ```
  iex> {:ok, bucket} = WaifuVault.create_bucket()
  {:ok, "some-uuid-type-value"}
  ```
  """
  @doc group: "Buckets"
  def create_bucket() do
    case Req.get(@request_options, url: "/bucket/create") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, bucket_response_from_map(body)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
  Deleting a bucket will delete the bucket and all the files it contains.

  IMPORTANT: All contained files will be DELETED along with the Bucket!

  ```
  iex> {:ok, boolean} = WaifuVault.delete_bucket("some-valid-uuid-token")
  {:ok, true}
  ```
  """
  @doc group: "Buckets"
  def delete_bucket(token) do
    case Req.delete(@request_options, url: "/bucket/#{token}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body in [true, "true"]}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
  The get_bucket/1 function returns the list of files and albums contained in a bucket.
  Try it out in iex to see what it returns, which is fairly
  self-explanatory - except for:
    
  * `dateCreated` - can be converted with `DateTime.from_unix( dateCreated, :millisecond)`
  * `retentionPeriod` - in milliseconds

  ```
  iex> {:ok, boolean} = WaifuVault.get_bucket("some-valid-uuid-token")
  {:ok, Map}
  ```
  """
  @doc group: "Buckets"
  def get_bucket(token) do
    case Req.post(@request_options, url: "/bucket/get", json: %{"bucket_token" => token}) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, bucket_response_from_map(body)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  # === handle_error
  # Handle errors similarly to the Python API
  @doc false
  def handle_error(req_response, is_download \\ false)

  def handle_error({_, %Req.Response{status: 403}}, true) do
    {:error, "Error 403 (Password is Incorrect): Password is Incorrect"}
  end

  def handle_error(
        {_,
         %Req.Response{body: %{"message" => message, "status" => body_status, "name" => name}}},
        false
      ) do
    {:error, "Error #{body_status} (#{name}): #{message}"}
  end

  def handle_error({_, %Req.Response{status: status, body: body}}, false) do
    [message, body_status, name] =
      case Jason.decode(body) do
        {:ok, %{"message" => b_message, "status" => b_status, "name" => b_name}} ->
          [b_message, b_status, b_name]

        _ ->
          [status, body, status]
      end

    {:error, "Error #{body_status} (#{name}): #{message}"}
  end

  def handle_error({:error, unexpected}, _) do
    {:error, "Unexpected Error #{inspect(unexpected)}"}
  end

  # === XYZ_response_from_map
  # Convert string-keyed camelCase responses to atom-keyed camelCase maps
  @doc false
  def bucket_response_from_map(map) do
    %{
      token: map["token"],
      files: Enum.map(map["files"] || [], &file_response_from_map/1),
      albums: Enum.map(map["albums"] || [], &album_response_from_map/1)
    }
  end

  @doc false
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

  @doc false
  def album_response_from_map(map) do
    %{
      # Will this be needed by get_album ?
      # files: Enum.map(map["files"] || [], &file_response_from_map/1),
      token: map["token"],
      bucketToken: map["bucket"],
      publicToken: map["publicToken"],
      name: map["name"],
      dateCreated: map["dateCreated"]
    }
  end

  @doc false
  def file_options_from_map(map) do
    %{
      hideFilename: map["hideFilename"] || false,
      oneTimeDownload: map["oneTimeDownload"] || false,
      protected: map["oneTimeDownload"] || false
    }
  end
end
