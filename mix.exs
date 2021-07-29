defmodule Stemmer.Mixfile do
  use Mix.Project

  def project do
    [ app: :stemmer,
      version: "1.0.0",
      elixir: "~> 1.12",
      deps: deps() ]
  end

  # Configuration for the OTP application
  def application do
    []
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "~> 0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps() do
    []
  end
end
