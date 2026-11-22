defmodule Prosody.Error do
  @moduledoc """
  Exceptions raised by Prosody.

  Includes the error reason and the phase (`:parse`, `:analyze`, or `:summarize`).
  """

  defexception [:phase, :reason]

  @type t :: %__MODULE__{
          phase: :parse | :analyze | :summarize,
          reason: String.t()
        }

  def message(%__MODULE__{phase: phase, reason: reason}) do
    "#{phase} failed: #{reason}"
  end
end
