defmodule WaifuVault do
  @moduledoc """
    This API wrapper is meant to conform to the [WaifuVault Swagger docs](https://waifuvault.moe/api-docs/).

    To include in your project:
    ```
    # In your mix.exs deps/0 function
    {:waifu_vault, "~> 0.0.2"}
    ```

    To Use:
    ```
    # In your_file.ex
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

  @restriction_keys [:type, :value]
  @file_info_keys [:recordCount, :recordSize]

  @doc """
    Buckets are virtual collections that are linked to your IP and a token. When you create a bucket, you will receive a bucket token that you can use in Get Bucket to get all the files in that bucket

    NOTE: Only one bucket is allowed per client IP address, if you call it more than once, it will return the same bucket token

    To create a bucket, use the create_bucket function. This function does not take any arguments.

    ## Examples
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

    ## Examples
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
    The bucket has a `dateCreated` value that can be converted
    with `DateTime.from_unix( dateCreated, :millisecond)`

    Individual files have a `retentionPeriod` which is the UNIX timestamp in milliseconds for when the
    file will expire. It can be converted with `DateTime.from_unix( retentionPeriod, :millisecond)`

    ## Examples
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

  @doc """
    The create_album/2 creates an album within the specified bucket.

    ## Examples
    ```
    iex> {:ok, album} = WaifuVault.create_album("some-bucket-token", "album-name")
    {:ok, Map}
    ```
  """
  @doc group: "Albums"
  def create_album(bucket_token, album_name) do
    case Req.post(@request_options, url: "/album/#{bucket_token}", json: %{"name" => album_name}) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, album_response_from_map(body, [])}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
      The delete_album/2 removes the specified album

      ## Examples
      ```
      # First deletion attempt
      iex> WaifuVault.delete_album("album-token")
      {:ok, %{"description" => "album deleted", "success" => true}}

      # Attempt a second deletion
      iex> WaifuVault.delete_album("album-token")
      {:error,
      "Error 400 (BAD_REQUEST): Album with token album-token not found"}
      ```
  """
  @doc group: "Albums"
  def delete_album(album_token, delete_files \\ false) do
    case Req.delete(@request_options,
           url: "/album/#{album_token}?deleteFiles=#{delete_files == true}"
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The get_album/1 function returns album info, given either the public or private token.

    ## Examples
    ```
    iex> {:ok, album_response} = WaifuVault.get_album("some-valid-album-token")
    {:ok, Map}
    ```
  """
  @doc group: "Albums"
  def get_album(token) do
    case Req.get(@request_options, url: "/album/#{token}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        files = Enum.map(body["files"] || [], &file_response_from_map/1)
        {:ok, album_response_from_map(body, files)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The associate_file/2 function connects one or more files to an album.

    ## Examples
    ```
    iex> {:ok, album_response} = WaifuVault.associate_file("some-valid-album-token", ["valid-file1". "valid-file2"])
    {:ok, Map}
    ```
  """
  @doc group: "Albums"
  def associate_file(album_token, file_tokens) do
    case Req.post(@request_options,
           url: "/album/#{album_token}/associate",
           json: %{"fileTokens" => file_tokens}
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        files = Enum.map(body["files"] || [], &file_response_from_map/1)
        {:ok, album_response_from_map(body, files)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The disassociate_file/2 function connects one or more files to an album.

    ## Examples
    ```
    iex> {:ok, album_response} = WaifuVault.disassociate_file("some-valid-album-token", ["valid-file1". "valid-file2"])
    {:ok, Map}
    ```
  """
  @doc group: "Albums"
  def disassociate_file(album_token, file_tokens) do
    case Req.post(@request_options,
           url: "/album/#{album_token}/disassociate",
           json: %{"fileTokens" => file_tokens}
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        files = Enum.map(body["files"] || [], &file_response_from_map/1)
        {:ok, album_response_from_map(body, files)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The share_album/2 function takes the album's private token and returns the public URL.
    Note that the newly-created public token is available via get_album/1
    (or, apparently, from just sharing again).

    ## Examples (unclear if the 2nd response is a bug)
    ```
    iex> {:ok, url} = WaifuVault.share_album("some-valid-album-token")
    {:ok, "https://waifuvault.moe/public-token"}
    iex> {:ok, url} = WaifuVault.share_album("some-valid-album-token")
    {:ok, "public-token"}
    ```
  """
  @doc group: "Albums"
  def share_album(album_token) do
    case Req.get(@request_options, url: "/album/share/#{album_token}") do
      {:ok, %Req.Response{status: 200, body: %{"description" => description, "success" => true}}} ->
        {:ok, description}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The revoke_album/2 function disables public sharing.
    Note that the next call to get_album/1 will show a `nil` public token.

    ## Examples
    ```
    iex> {:ok, album_response} = WaifuVault.revoke_album("some-valid-album-token")
    {:ok, "album unshared"}
    ```
  """
  @doc group: "Albums"
  def revoke_album(album_token) do
    case Req.get(@request_options, url: "/album/revoke/#{album_token}") do
      {:ok, %Req.Response{status: 200, body: %{"description" => description, "success" => true}}} ->
        {:ok, description}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The get_file/2 function retrieves the specified file. The password is ignored unless
    the file is password-protected.

    ## Examples
    ```
    iex> {:ok, bitstring} = WaifuVault.get_file("some-valid-album-token", "some-password")
    {:ok, <<many bytes>>}
    ```
  """
  @doc group: "Files"
  def get_file(album_response, password \\ nil)

  def get_file(%{url: url}, nil) do
    _get_file(%{url: url})
  end

  def get_file(%{url: url}, password) do
    _get_file(%{url: url}, %{"x-password" => password})
  end

  def get_file(%{token: token}, _password) do
    with {:ok, map} = file_info(token),
         {:ok, file_contents} = get_file(map) do
      {:ok, file_contents}
    end
  end

  @doc false
  def _get_file(request_fields, headers \\ nil) do
    req =
      (is_nil(headers) && @request_options) ||
        Req.merge(@request_options, headers: headers)

    case Req.get(req, Map.to_list(request_fields)) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The file_info/2 function retrieves fileResponse data for the specified file token.

    ## Examples
    ```
    iex> {:ok, map} = WaifuVault.file_info("some-valid-file-token")
    {:ok, %{...}}
    ```
  """
  @doc group: "Files"
  def file_info(token, formatted \\ false) do
    case Req.get(@request_options, url: "/#{token}", json: %{formatted: "#{formatted == true}"}) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, file_response_from_map(body)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The get_restrictions/0 function returns server limits for the current IP address.

    ## Examples
    ```
    iex> {:ok, restrictions} = WaifuVault.get_restrictions()
    {:ok,
      [
        %{type: "MAX_FILE_SIZE", value: 104857600},
        %{
          type: "BANNED_MIME_TYPE",
          value: "application/x-dosexec,application/x-executable,application/x-hdf5,application/x-java-archive,application/vnd.rar"
        }
      ]
    }
    ```
  """
  @doc group: "Resources"
  def get_restrictions() do
    case Req.get(@request_options, url: "/resources/restrictions") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok,
         Enum.map(body, fn restriction ->
           convert_to_atom_keys(restriction, @restriction_keys)
         end)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
    The get_file_stats/0 function returns server limits for the current IP address.

    ## Examples
    ```
    iex> WaifuVault.get_file_stats
    {:ok, %{"recordCount" => 1420, "recordSize" => "1.92 GiB"}}
    ```
  """
  @doc group: "Resources"
  def get_file_stats() do
    case Req.get(@request_options, url: "/resources/stats/files") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, convert_to_atom_keys(body, @file_info_keys)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc false
  def convert_to_atom_keys(map, atoms) do
    strings = Enum.map(atoms, fn atom -> "#{atom}" end)

    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if key in strings do
        put_in(acc, [String.to_existing_atom(key)], value)
      else
        acc
      end
    end)
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
    files = Enum.map(map["files"] || [], &file_response_from_map/1)

    %{
      token: map["token"],
      files: files,
      albums: Enum.map(map["albums"] || [], fn album -> album_response_from_map(album, files) end)
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
      album: album_response_from_map(map["album"] || %{}, []),
      options: file_options_from_map(map["options"] || %{})
    }
  end

  @doc false
  def album_response_from_map(map, _) when map == %{}, do: nil

  def album_response_from_map(map, files) do
    album_token = map["token"]

    %{
      token: album_token,
      bucketToken: map["bucket"] || map["bucketToken"],
      publicToken: map["publicToken"],
      name: map["name"],
      dateCreated: map["dateCreated"],
      files:
        Enum.filter(files, fn file ->
          is_nil(file.album) || file.album.token in [nil, album_token]
        end)
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
