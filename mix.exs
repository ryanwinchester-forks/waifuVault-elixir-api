defmodule WaifuVault.MixProject do
  use Mix.Project

  def project do
    [
      app: :waifu_vault,
      version: "0.0.1",
      elixir: "~> 1.16",
      description: "API wrapper for waifuvault.moe",
      package: %{
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/waifuvault/waifuVault-elixir-api",
          "Swagger" => "https://waifuvault.moe/api-docs/",
          "Web Site" => "https://waifuvault.moe/"
        }
      },
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: []
    ]
  end

  def description do
    """
    API wrapper for https://waifuvault.moe/
    """
  end

  def package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["John Baylor"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/waifuvault/waifuVault-elixir-api",
        "Swagger" => "https://waifuvault.moe/api-docs/",
        "Web Site" => "https://waifuvault.moe/"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.8"},
      {:plug, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
