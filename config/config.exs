import Config

config :waifu_vault, WaifuVault, base_url: "https://example.com/rest"

# Import environment-specific config files, if they exist.
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
