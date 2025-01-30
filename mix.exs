defmodule WaifuVault.MixProject do
  use Mix.Project

  def project do
    [
      app: :waifu_vault,
      version: "0.0.1",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: []
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
