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

  # Real data, with minor modifications
  @example_bucket_token "111d81d4-22c6-43f8-bba4-b82a3ef52ce3"
  @example_album_token "de1c61c6-1321-4ec6-bafa-626ae1bca1d3"
  @example_file_token "f1bc1b41-1b87-4db1-b00d-fea7e610bdcb"
  @get_bucket_example %{
    albums: [
      %{
        bucket: @example_bucket_token,
        dateCreated: 1_738_201_401_000,
        name: "some-album",
        publicToken: nil,
        token: @example_album_token
      }
    ],
    files: [
      %{
        album: %{
          bucket: @example_bucket_token,
          dateCreated: 1_738_201_401_000,
          name: "some-album",
          publicToken: nil,
          token: @example_album_token
        },
        bucket: @example_bucket_token,
        options: %{
          hideFilename: false,
          oneTimeDownload: false,
          protected: false
        },
        retentionPeriod: 28_732_211_121,
        token: @example_file_token,
        url: "https://example.com/f/1738201375511/frog.jpg",
        views: 1
      },
      %{
        album: %{
          bucket: @example_bucket_token,
          dateCreated: 1_738_201_401_000,
          name: "some-album",
          publicToken: nil,
          token: @example_album_token
        },
        bucket: @example_bucket_token,
        options: %{
          hideFilename: false,
          oneTimeDownload: false,
          protected: false
        },
        retentionPeriod: 27_617_033_528,
        token: "1f18b1ee-42cf-4842-1cd7-0aa0763125e5",
        url: "https://example.com/f/1738201375845/hot%20guitarist.png",
        views: 4
      }
    ],
    token: @example_bucket_token
  }
  @example_file_info %{
    album: nil,
    bucket: @example_bucket_token,
    options: %{
      hideFilename: false,
      oneTimeDownload: false,
      protected: false
    },
    retentionPeriod: 28_644_786_051,
    token: @example_file_token,
    url: "https://example.com/f/1738201375511/frog.jpg",
    views: 1
  }

  @get_album_example %{
    bucketToken: @example_bucket_token,
    dateCreated: 1_738_201_401_000,
    files: [
      @example_file_info,
      %{
        album: nil,
        bucket: @example_bucket_token,
        options: %{
          hideFilename: false,
          oneTimeDownload: false,
          protected: false
        },
        retentionPeriod: 28_633_011_767,
        token: "ed02f1c8-8142-4e35-abb7-73e1c0a2ba11",
        url: "https://example.com/f/1738201376708/balls.jpg",
        views: 1
      }
    ],
    name: "test-album",
    publicToken: nil,
    token: @example_album_token
  }
  @test_max_file_size 10_000
  @restrictions_response [
    %{type: "MAX_FILE_SIZE", value: @test_max_file_size},
    %{
      type: "BANNED_MIME_TYPE",
      value:
        "application/x-dosexec,application/x-executable,application/x-hdf5,application/x-java-archive,application/vnd.rar"
    }
  ]

  @file_stats_response %{recordCount: 1420, recordSize: "1.92 GiB"}

  describe "create_bucket/0" do
    test "bucket is created" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, %{"token" => "server-token"})
      end)

      {:ok, bucketResponse} = WaifuVault.create_bucket()

      refute is_nil(bucketResponse)
      assert bucketResponse.token == "server-token"
      assert bucketResponse.files == []
      assert bucketResponse.albums == []
    end

    test "creating twice returns the same bucket" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, %{"token" => "server-token"})
      end)

      {:ok, bucketResponse1} = WaifuVault.create_bucket()
      {:ok, bucketResponse2} = WaifuVault.create_bucket()

      refute is_nil(bucketResponse1)
      refute is_nil(bucketResponse1.token)
      assert bucketResponse1.token == bucketResponse2.token
    end
  end

  describe "get_bucket/1" do
    test "bucket details are returned" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @get_bucket_example)
      end)

      {:ok, bucketResponse} = WaifuVault.get_bucket(@example_bucket_token)

      refute is_nil(bucketResponse)
      assert bucketResponse.token == @example_bucket_token
      assert Enum.count(bucketResponse.files) == 2
      assert Enum.count(bucketResponse.albums) == 1
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

  describe "create_album/1" do
    test "album details are returned" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @get_album_example)
      end)

      {:ok, albumResponse} = WaifuVault.create_album(@example_bucket_token, "album-name")

      refute is_nil(albumResponse)
      assert albumResponse.token == @example_album_token
      assert albumResponse.bucketToken == @example_bucket_token
      assert Enum.count(albumResponse.files) == 0
    end
  end

  describe "delete_album/1" do
    test "album details are returned" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, %{"description" => "album deleted", "success" => true})
      end)

      {:ok, albumResponse} = WaifuVault.delete_album(@example_album_token)

      assert albumResponse == %{"description" => "album deleted", "success" => true}
    end
  end

  describe "get_album/1" do
    test "album details are returned" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @get_album_example)
      end)

      {:ok, albumResponse} = WaifuVault.get_album(@example_album_token)

      refute is_nil(albumResponse)
      assert albumResponse.token == @example_album_token
      assert albumResponse.bucketToken == @example_bucket_token
      assert Enum.count(albumResponse.files) == 2
    end
  end

  describe "associate_file/1" do
    test "album details are returned" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @get_album_example)
      end)

      {:ok, albumResponse} =
        WaifuVault.associate_file(@example_album_token, [@example_file_token])

      refute is_nil(albumResponse)
      assert albumResponse == @get_album_example
    end
  end

  describe "disassociate_file/1" do
    test "album details are returned" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @get_album_example)
      end)

      {:ok, albumResponse} =
        WaifuVault.disassociate_file(@example_album_token, ["file-token-to-disassociate"])

      refute is_nil(albumResponse)
      assert albumResponse == @get_album_example
    end
  end

  describe "share_album/1" do
    test "1st call returns the URL to the now-public album" do
      expected_url = "https://example.com/album/#{@example_album_token}"

      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, %{
          "description" => expected_url,
          "success" => true
        })
      end)

      {:ok, url} = WaifuVault.share_album(@example_album_token)

      assert url == expected_url
    end

    test "2nd call just returns the public token" do
      expected_url = "https://example.com/album/#{@example_album_token}"

      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, %{"description" => expected_url, "success" => true})
      )

      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, %{"description" => @example_album_token, "success" => true})
      )

      {:ok, url} = WaifuVault.share_album(@example_album_token)
      {:ok, public_token} = WaifuVault.share_album(@example_album_token)

      assert url == expected_url
      assert public_token == @example_album_token
    end
  end

  describe "revoke_album/1" do
    test "unshares the album" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, %{"description" => "album unshared", "success" => true})
      end)

      {:ok, message} = WaifuVault.revoke_album(@example_album_token)

      assert message == "album unshared"
    end
  end

  describe "get_file/2" do
    test "returns file data when given a URL" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, <<0x68, 0x65, 0x6C, 0x6C, 0x6F>>)
      end)

      {:ok, file_contents} = WaifuVault.get_file(%{url: "https://example.com/hello.txt"})

      refute is_nil(file_contents)
      assert file_contents == "hello"
    end

    test "returns file contents for an encrypted file when given a URL and password" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, "hello")
      end)

      {:ok, file_contents} =
        WaifuVault.get_file(%{url: "https://example.com/hello.txt"}, "valid-password")

      refute is_nil(file_contents)
      assert file_contents == <<0x68, 0x65, 0x6C, 0x6C, 0x6F>>
    end

    test "returns file contents when given a file token" do
      # It should make 2 requests: one for the file_info and then another for the contents.
      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, @example_file_info)
      )

      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, <<0x68, 0x65, 0x6C, 0x6C, 0x6F>>)
      )

      {:ok, file_contents} = WaifuVault.get_file(%{token: @example_file_info.token})

      refute is_nil(file_contents)
      assert file_contents == "hello"
    end
  end

  describe "file_info/2" do
    test "returns the file metadata" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @example_file_info)
      end)

      {:ok, map} = WaifuVault.file_info(@example_file_token)

      refute is_nil(map)
      assert map == @example_file_info
    end
  end

  describe "upload_file_from_buffer/3" do
    test "uploads the buffer of data" do
      # It should make 2 requests: one for restrictions and one for the upload
      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, @restrictions_response)
      )

      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, @example_file_info)
      )

      {:ok, map} = WaifuVault.upload_file_from_buffer("hello!", "world.txt")

      refute is_nil(map)
      assert map == @example_file_info
    end
  end

  describe "upload_local_file/3" do
    test "uploads the buffer of data" do
      # It should make 2 requests: one for restrictions and one for the upload
      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, @restrictions_response)
      )

      Req.Test.expect(
        WaifuVault,
        &Req.Test.json(&1, @example_file_info)
      )

      # Note: mix.exs is expected to be smaller than the @restrictions_response MAX_FILE_SIZE
      {:ok, map} = WaifuVault.upload_local_file("./mix.exs", "my_mix.exs")

      refute is_nil(map)
      assert map == @example_file_info
    end
  end

  describe "upload_via_url/2" do
    test "uploads the buffer of data" do
      test_url =
        "https://variety.com/wp-content/uploads/2020/01/taylor-swift-variety-cover-5-16x9-1000.jpg"

      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @example_file_info)
      end)

      {:ok, map} = WaifuVault.upload_via_url(test_url)

      refute is_nil(map)
      assert map == @example_file_info
    end
  end

  describe "upload_url/1" do
    test "adds options as URL params" do
      assert String.starts_with?(WaifuVault.upload_url(%{bucket_token: "aaabbb"}), "/aaabbb")
      assert String.contains?(WaifuVault.upload_url(%{expires: "5m"}), "expires=5m")

      assert String.contains?(
               WaifuVault.upload_url(%{one_time_download: true}),
               "oneTimeDownload=true"
             )

      assert String.contains?(WaifuVault.upload_url(%{hide_filename: true}), "hide_filename=true")
      assert String.starts_with?(WaifuVault.upload_url(%{expires: "3d"}), "/?")

      assert String.contains?(
               WaifuVault.upload_url(%{one_time_download: 343}),
               "oneTimeDownload=false"
             )

      assert String.contains?(
               WaifuVault.upload_url(%{hide_filename: "yellow"}),
               "hide_filename=false"
             )
    end
  end

  describe "ok_size?/2" do
    test "returns :ok when MAX_FILE_SIZE at least as large as needed" do
      assert :ok == WaifuVault.ok_size?(@restrictions_response, @test_max_file_size - 1)
      assert :ok == WaifuVault.ok_size?(@restrictions_response, @test_max_file_size)
    end

    test "returns :error when MAX_FILE_SIZE is smaller than needed" do
      assert {:error, _} = WaifuVault.ok_size?(@restrictions_response, @test_max_file_size + 1)
    end

    test "returns :error when MAX_FILE_SIZE is missing" do
      assert {:error, _} = WaifuVault.ok_size?([], 1)
    end
  end

  describe "mime_type_ok?/2" do
    test "returns :ok when BANNED_MIME_TYPE does not include file's mime type" do
      assert :ok == WaifuVault.mime_type_ok?(@restrictions_response, "some_file.jpg")
    end

    test "returns :error when BANNED_MIME_TYPE includes file's mime type" do
      assert {:error, _} = WaifuVault.mime_type_ok?(@restrictions_response, "some_file.rar")
    end

    test "returns :error when BANNED_MIME_TYPE is missing" do
      assert {:error, _} = WaifuVault.mime_type_ok?([], "some_file.txt")
    end
  end

  describe "update_file/2" do
    test "returns file response" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @example_file_info)
      end)

      {:ok, map} = WaifuVault.update_file("some-file-token", %{})

      refute is_nil(map)
      assert map == @example_file_info
    end
  end

  describe "delete_file/1" do
    test "returns true on successful deletion" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, true)
      end)

      {:ok, response} = WaifuVault.delete_file("valid-token")

      assert response == true
    end

    test "returns error for unknown file token" do
      Req.Test.stub(WaifuVault, fn conn ->
        Plug.Conn.send_resp(
          conn,
          400,
          Jason.encode_to_iodata!(%{
            "status" => "400",
            "name" => "BAD_REQUEST",
            "message" => "Unknown token invalid-token"
          })
        )
      end)

      {:error, response} = WaifuVault.delete_file("invalid-token")

      assert response == "Error 400 (BAD_REQUEST): Unknown token invalid-token"
    end
  end

  describe "get_restrictions/0" do
    test "response with plenty of space" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @restrictions_response)
      end)

      {:ok, restrictions} = WaifuVault.get_restrictions()

      refute is_nil(restrictions)
      assert restrictions == @restrictions_response
    end
  end

  describe "get_file_stats/0" do
    test "response with plenty of space" do
      Req.Test.stub(WaifuVault, fn conn ->
        Req.Test.json(conn, @file_stats_response)
      end)

      {:ok, file_stats} = WaifuVault.get_file_stats()

      refute is_nil(file_stats)
      assert file_stats == @file_stats_response
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
