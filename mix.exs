defmodule VCNL4040.MixProject do
  use Mix.Project

  def project do
    [
      app: :vcnl4040,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "VCNL4040",
      description: "Driver for the VCNL4040 ambient light and proximity sensor",
      source_url: "https://github.com/underjord/vcnl4040",
      docs: [
        # The main page in the docs
        main: "VCNL4040",
        extras: ["README.md"]
      ],
      package: [
        name: :vcnl4040,
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/underjord/vcnl4040"}
      ]
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
      {:circuits_i2c, "~> 2.0"},
      {:circuits_gpio, "~> 2.0"},
      {:circular_buffer, "~> 0.4.1"}
    ]
  end
end
