defmodule Annotator.DataGridSchema do
  @doc "data for an annotator interface"
  @enforce_keys [:content]

  defstruct [
      line_number: 1,
      content: "",
      note: ""
  ]
  @type t :: %__MODULE__{line_number: non_neg_integer, content: String.t(), note: String.t()}
end
