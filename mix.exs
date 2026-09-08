defmodule DBus.MixProject do
  use Mix.Project

  @source_url "https://github.com/mpotra/ex_dbus"

  def project do
    [
      app: :ex_dbus,
      version: "0.1.4",
      elixir: ">= 1.11.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      source_url: @source_url,
      description: "Elixir implementation of D-Bus",
      package: package(),
      deps: deps(),
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts"
      ],
      name: "ExDBus",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: &docs/0
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:dev), do: ["lib", "examples"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dbus, github: "jeanparpaillon/erlang-dbus", branch: "next"},
      # {:dbus, "~> 0.8.0"},
      {:saxy, "~> 1.6.0"},

      # Development
      {:dialyxir, "~> 1.4.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp package do
    [
      maintainers: ["Mihai Potra"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
