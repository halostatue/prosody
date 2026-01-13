defmodule Prosody.MixProject do
  use Mix.Project

  @app :prosody
  @project_url "https://github.com/halostatue/prosody"
  @version "1.0.1"

  def project do
    [
      app: @app,
      description:
        "Content analysis library for measuring reading flow and cognitive load in mixed text and code content",
      version: @version,
      source_url: @project_url,
      name: "Prosody",
      elixir: "~> 1.18",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      test_coverage: test_coverage(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_local_path: "priv/plts/project.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Austin Ziegler"],
      licenses: ["Apache-2.0"],
      files: ~w(lib .formatter.exs mix.exs *.md licences),
      links: %{
        "Source" => @project_url,
        "Issues" => @project_url <> "/issues"
      }
    ]
  end

  defp deps do
    [
      {:mdex, "~> 0.9", optional: true},
      {:mdex_gfm, "~> 0.1", optional: true},
      {:tableau, "~> 0.27", optional: true},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:ex_doc, "~> 0.29", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Prosody",
      extras: [
        "README.md",
        "CONTRIBUTING.md": [filename: "CONTRIBUTING.md", title: "Contributing"],
        "CODE_OF_CONDUCT.md": [filename: "CODE_OF_CONDUCT.md", title: "Code of Conduct"],
        "CHANGELOG.md": [filename: "CHANGELOG.md", title: "CHANGELOG"],
        "LICENCE.md": [filename: "LICENCE.md", title: "Licence"],
        "licences/APACHE-2.0.txt": [
          filename: "APACHE-2.0.txt",
          title: "Apache License, version 2.0"
        ],
        "licences/algorithms-mit.txt": [
          filename: "algorithms-mit.txt",
          title: "MIT License (for The Algorithms fixture files)"
        ],
        "licences/dco.txt": [filename: "dco.txt", title: "Developer Certificate of Origin"]
      ],
      source_ref: "v#{@version}",
      source_url: @project_url,
      canonical: "https://hexdocs.pm/#{@app}"
    ]
  end

  defp test_coverage do
    [
      tool: ExCoveralls
    ]
  end
end
