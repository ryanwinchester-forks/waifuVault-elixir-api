import Config

# Ensure tests don't hit the real server by using `Req.Test` to intercept all
# HTTP calls.
config :waifu_vault, WaifuVault,
  base_url: "https://example.com/rest",
  plug: {Req.Test, WaifuVault}

# Print only errors during tests.
config :logger, level: :error
