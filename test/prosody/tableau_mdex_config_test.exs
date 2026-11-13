defmodule Prosody.TableauMDExConfigTest do
  # Mutates the :tableau application environment.
  use ExUnit.Case, async: false

  alias Prosody.Tableau.MDExParser

  @content "# Test\n\n~~Content~~"

  setup do
    previous = Application.fetch_env(:tableau, Tableau.MDExExtension)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:tableau, Tableau.MDExExtension, value)
        :error -> Application.delete_env(:tableau, Tableau.MDExExtension)
      end
    end)
  end

  test "uses config :tableau, Tableau.MDExExtension" do
    Application.put_env(:tableau, Tableau.MDExExtension, extension: [strikethrough: true])

    assert {:ok, [%{content: "Test"}, %{content: "Content"}]} = MDExParser.parse(@content)
    assert {:ok, [%{content: "Test"}, %{content: "Content"}]} = MDExParser.parse(@content, site: %{})
  end

  test "Tableau.MDExExtension config takes precedence over legacy site markdown config" do
    Application.put_env(:tableau, Tableau.MDExExtension, extension: [strikethrough: false])

    legacy_site = %{markdown: [mdex: [extension: [strikethrough: true]]]}

    assert {:ok, [%{content: "Test"}, %{content: "~~Content~~"}]} =
             MDExParser.parse(@content, site: legacy_site)
  end

  test "explicit opts override Tableau.MDExExtension config" do
    Application.put_env(:tableau, Tableau.MDExExtension, extension: [strikethrough: true])

    assert {:ok, [%{content: "Test"}, %{content: "~~Content~~"}]} =
             MDExParser.parse(@content, extension: [strikethrough: false])
  end
end
