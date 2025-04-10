import Config

config :waifu_vault, WaifuVault,
  base_url: "https://example.com/rest",
  plug: {Req.Test, WaifuVault}
