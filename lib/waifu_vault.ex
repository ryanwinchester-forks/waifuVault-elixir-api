defmodule WaifuVault do
  @moduledoc """
  This API wrapper is meant to conform to the [WaifuVault Swagger docs](https://waifuvault.moe/api-docs/).

  ### To include in your project:

  In your mix.exs deps/0 function

      {:waifu_vault, "~> 1.0.0"}


  ### To Use:

  In your_file.ex

      require WaifuVault

  """

  require Logger
  require Multipart

  @request_options Req.new(Application.compile_env!(:waifu_vault, __MODULE__))

  @restriction_keys [:type, :value]
  @file_info_keys [:recordCount, :recordSize]
  @upload_status %{
    200 => "File already exists",
    201 => "New file stored successfully"
  }
  @file_update_keys [:password, :previousPassword, :customExpiry, :hideFilename]

  @doc """
  Creates a bucket.

  Buckets are virtual collections that are linked to your IP and a token. When you create a bucket,
  you will receive a bucket token that you can use in get_bucket/1 to get all the files in that bucket.
  Later calls to create_bucket/0 will return the same token as long as your IP address doesn't change.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Bucket%20Management/bucketManagementCreateBucket)

  ## Examples

      iex> {:ok, bucket} = WaifuVault.create_bucket()
      {:ok, "some-uuid-type-value"}

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
  [Swagger docs](https://waifuvault.moe/api-docs/#/Bucket%20Management/bucketManagementDeleteBucket)

  IMPORTANT: All contained files will be DELETED along with the Bucket!

  ## Examples

      iex> {:ok, boolean} = WaifuVault.delete_bucket("some-valid-uuid-token")
      {:ok, true}

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
  Returns the list of files and albums contained in a bucket.

  The bucket has a `dateCreated` value that can be converted
  with `DateTime.from_unix( dateCreated, :millisecond)`
  [Swagger docs](https://waifuvault.moe/api-docs/#/Bucket%20Management/bucketManagementGetBucket)

  Individual files have a `retentionPeriod` which is the UNIX timestamp in milliseconds for when the
  file will expire. It can be converted with `DateTime.from_unix( retentionPeriod, :millisecond)`

  ## Examples

      iex> WaifuVault.get_bucket("some-valid-uuid-token")
      {:ok, %{...}}

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
  Creates an album within the specified bucket.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementCreateAlbum)

  ## Examples
    
    iex> WaifuVault.create_album("some-bucket-token", "album-name")
    {:ok, Map}
   
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
  Removes the specified album.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementDeleteAlbum)

  ## Examples

      # First deletion attempt
      iex> WaifuVault.delete_album("album-token")
      {:ok, %{"description" => "album deleted", "success" => true}}

      # Attempt a second deletion
      iex> WaifuVault.delete_album("album-token")
      {:error, "Error 400 (BAD_REQUEST): Album with token album-token not found"}

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
  Get album info, given the private token.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementGetAlbum)

      iex> WaifuVault.get_album("some-valid-album-token")
      {:ok, %{...}}

  """
  @doc group: "Albums"
  def get_album(album_token) do
    case Req.get(@request_options, url: "/album/#{album_token}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        files = Enum.map(body["files"] || [], &file_response_from_map/1)
        {:ok, album_response_from_map(body, files)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
  Connects one or more files to an album.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementAssociateFileWithAlbum)

  ## Examples

      iex> WaifuVault.associate_file("some-valid-album-token", ["valid-file1". "valid-file2"])
      {:ok, %{...}}

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
  Disconnects one or more files from an album.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementDisassociateFileWithAlbum)

  ## Examples

      iex> WaifuVault.disassociate_file("some-valid-album-token", ["valid-file1". "valid-file2"])
      {:ok, %{...}}

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
  Takes the album's private token and returns the public URL.
  Calling `share_album/1` on an already-shared album will just return its token.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementShareAlbum)

  ## Examples

      iex> WaifuVault.share_album("some-valid-album-token")
      {:ok, "https://waifuvault.moe/public-token"}

      iex> WaifuVault.share_album("some-valid-album-token")
      {:ok, "public-token"}

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
  Disables public sharing.
  Note that future calls to share_album/1 will give it a new public token and new public URL.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementRevokeShare)

  ## Examples

      iex> WaifuVault.revoke_album("some-valid-album-token")
      {:ok, "album unshared"}

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
  Fetches a zip file containing either the whole album, or specified files.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Album%20management/albumManagementDownloadFiles)

  ## Examples

      iex> WaifuVault.download_album("some-valid-album-token", ["file.jpg", "file2.jpg"])
      {:ok, <<...>>}

  """
  @doc group: "Albums"
  def download_album(album_token, file_names \\ []) do
    case Req.post(@request_options,
           url: "/album/download/#{album_token}",
           json: file_names,
           into: :self
         ) do
      {:ok, %Req.Response{status: 200, body: _body} = response} ->
        Logger.debug(inspect(response, pretty: true))
        zip_data = Enum.reduce(response.body, "", fn stream, acc -> acc <> stream end)

        file_name =
          Req.Response.get_header(response, "content-disposition")
          |> List.first()
          |> String.split("\"")
          |> Enum.slice(-2, 1)
          |> List.first()

        {:ok, file_name, zip_data}

      any_other_response ->
        Logger.debug(inspect(any_other_response))
        handle_error(any_other_response, true)
    end
  end

  @doc """
  Retrieves the contents of the specified file, which can be specified via URL or by token
  (which is used to *look up* the URL).

  The password, if passed, is ignored unless the file is password-protected.
  [Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadGetInfo)

  ## Examples

    iex> WaifuVault.get_file("some-valid-album-token", "some-password")
    {:ok, <<...>>}

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
         {:ok, file_contents} = get_file(map, map["password"]) do
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
        handle_error(any_other_response, true)
    end
  end

  @doc """
  Retrieves file metadata for the specified file token.
  [Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadGetInfo)

  ## Examples

      iex> WaifuVault.file_info("some-valid-file-token")
      {:ok, %{...}}

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
  Posts the data to the server, returning a fileResponse map.
  [Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadAddEntry)
  [and parallel Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadAddEntry_1)

  ## Examples

      iex> {:ok, buffer} = File.read("some/local/file")
      iex> {:ok, fileResponse} = WaifuVault.upload_file_from_buffer(buffer, "file.name", %{expires: "10m"})
      {:ok, %{...}}

  """
  @doc group: "Files"
  def upload_file_from_buffer(buffer, file_name, options \\ %{}) do
    multipart =
      if is_nil(options[:password]) do
        Multipart.new()
        |> Multipart.add_part(
          Multipart.Part.file_content_field(file_name, buffer, :file, filename: file_name)
        )
      else
        Multipart.new()
        |> Multipart.add_part(
          Multipart.Part.file_content_field(file_name, buffer, :file, filename: file_name)
        )
        |> Multipart.add_part(Multipart.Part.text_field(options[:password], :password))
      end

    content_length = Multipart.content_length(multipart)
    content_type = Multipart.content_type(multipart, "multipart/form-data")

    headers = [
      {"Content-Type", content_type},
      {"Content-Length", to_string(content_length)}
    ]

    # Check our restrictions before attempting an upload
    with {:get_restrictions, {:ok, restrictions}} <- {:get_restrictions, get_restrictions()},
         :ok <- ok_size?(restrictions, byte_size(buffer)),
         :ok <- mime_type_ok?(restrictions, file_name),
         {:ok, %Req.Response{status: status, body: body}} <-
           Req.put(@request_options,
             url: upload_url(options),
             #             json: (is_nil(options[:password]) && %{} || %{password: options[:password]}),
             headers: headers,
             body: Multipart.body_stream(multipart)
           ) do
      Logger.debug("Status #{status} means #{@upload_status[status] || "UNKNOWN"}")
      {:ok, file_response_from_map(body)}
    else
      {:get_restrictions, error} ->
        {:error, "Unable to get restrictions", error}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
  Simplifies the process of uploading a local file with a simple
  wrapper around `upload_file_from_buffer/3`. It posts the data to the server, returning a fileResponse map.
  [Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadAddEntry)
  [and parallel Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadAddEntry_1)

  ## Examples

      iex> options = %{}
      iex> WaifuVault.upload_local_file("./mix.exs", "my_mix.exs", options)
      {:ok, %{...}}

  """
  @doc group: "Files"
  def upload_local_file(local_path, file_name, options \\ %{}) do
    case File.read(local_path) do
      {:ok, buffer} ->
        upload_file_from_buffer(buffer, file_name, options)

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
  Uploading a file specified via URL. Setting the `:bucket` option will place the file
  in the specified bucket (assuming it exists).
  [Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadAddEntry)
  [and parallel Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadAddEntry_1)

  ## Examples

      iex> options = %{}
      iex> WaifuVault.upload_via_url(image_url, options)
      {:ok, %{...}}

  """
  @doc group: "Files"
  def upload_via_url(url, options \\ %{}) do
    json_data =
      if is_nil(options[:password]) do
        %{url: url}
      else
        %{url: url, password: options[:password]}
      end

    # no restrictions check - let the server do it.
    case Req.put(@request_options,
           url: upload_url(options),
           json: json_data
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.debug("File already exists")
        {:ok, file_response_from_map(body)}

      {:ok, %Req.Response{status: 201, body: body}} ->
        Logger.debug("New file stored successfully")
        {:ok, file_response_from_map(body)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc false
  def upload_url(options) do
    # NOTE: there are known inconsistencies between the snake-case "hide_filename"
    # and camel-case "oneTimeDownload" - but the options hash is snake-case.
    expires = (is_nil(options[:expires]) && "") || "expires=#{options[:expires]}&"

    hide_filename =
      (is_nil(options[:hide_filename]) && "") ||
        "hide_filename=#{options[:hide_filename] == true}&"

    oneTimeDownload =
      (is_nil(options[:one_time_download]) && "") ||
        "oneTimeDownload=#{options[:one_time_download] == true}"

    "/#{options[:bucket_token]}?#{expires}#{hide_filename}#{oneTimeDownload}"
  end

  @doc false
  def ok_size?(restrictions, file_size) do
    max_file_size =
      Enum.find(restrictions, fn %{type: type, value: _value} -> type == "MAX_FILE_SIZE" end)

    cond do
      is_nil(max_file_size) || is_nil(max_file_size.value) ->
        {:error, "Missing MAX_FILE_SIZE restriction"}

      max_file_size.value < file_size ->
        {:error, "File size #{file_size} is larger than max allowed #{max_file_size.value}"}

      true ->
        :ok
    end
  end

  @doc false
  def mime_type_ok?(restrictions, file_name) do
    mime_type = MIME.from_path(file_name)

    banned_entry =
      Enum.find(restrictions, fn %{type: type, value: _value} -> type == "BANNED_MIME_TYPE" end)

    cond do
      is_nil(banned_entry) || is_nil(banned_entry.value) ->
        {:error, "Missing BANNED_MIME_TYPE restriction"}

      String.contains?(banned_entry.value, mime_type) ->
        {:error, "File MIME type #{mime_type} is not allowed for upload"}

      true ->
        :ok
    end
  end

  @doc """
  Updates a file.
  Returns `{:ok, file_data}` for a successful update.
  [Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadModifyEntry)

  ## Examples

      iex> WaifuVault.update_file(file_token, %{...})
      {:ok, true}

  """
  @doc group: "Files"
  def update_file(file_token, options) do
    json_data =
      Enum.filter(options, fn {key, _value} -> key in @file_update_keys end)
      |> Map.new()

    case Req.patch(@request_options, url: "/#{file_token}", json: json_data) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, file_response_from_map(body)}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
  Returns `{:ok, true}` for a successful deletion.
  [Swagger docs](https://waifuvault.moe/api-docs/#/File%20Upload/fileUploadDeleteEntry)

  ## Examples

      iex> WaifuVault.delete_file(file_token)
      {:ok, true}

  """
  @doc group: "Files"
  def delete_file(file_token) do
    case Req.delete(@request_options, url: "/#{file_token}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.debug("raw delete response: " <> inspect(body))
        {:ok, body}

      any_other_response ->
        handle_error(any_other_response)
    end
  end

  @doc """
  Returns restrictions for the current IP address.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Resource%20Management/resourceManagementGetRestrictions)

  ## Examples

      iex> WaifuVault.get_restrictions()
      {:ok,
        [
          %{type: "MAX_FILE_SIZE", value: 104857600},
          %{
            type: "BANNED_MIME_TYPE",
            value: "application/x-dosexec,application/x-executable,application/x-hdf5,application/x-java-archive,application/vnd.rar"
          }
        ]
      }

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
  Returns server limits for the current IP address.
  [Swagger docs](https://waifuvault.moe/api-docs/#/Resource%20Management/resourceManagementStorage)

  ## Examples

      iex> WaifuVault.get_file_stats
      {:ok, %{"recordCount" => 1420, "recordSize" => "1.92 GiB"}}

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

  def handle_error({_, %Req.Response{body: %Req.Response.Async{} = async}}, true) do
    body = Enum.reduce(async, "", fn stream, acc -> acc <> stream end)
    Logger.debug("handle_error async body: " <> inspect(body))

    {:error, body}
  end

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
      protected: map["protected"] || false
    }
  end
end
