defmodule Prosody.Error do
  @moduledoc """
  Exception that may be raised during Prosody processing. Includes the underlying reason
  and the phase of execution (`:parse`, `:analyze`, or `:summarize`)
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
