defmodule NFTMediaHandlerDispatcher.MixProject do
  use Mix.Project

  def project do
    [
      app: :nft_media_handler_dispatcher,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {NFTMediaHandlerDispatcher.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:explorer, in_umbrella: true}
    ]
  end
end
