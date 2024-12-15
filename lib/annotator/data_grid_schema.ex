defmodule Annotator.DataGridSchemaDontNeedThisDoI do
  @doc "data for an annotator interface"

  defstruct [:id, lines: []]

  defmodule Line do
    @enforce_keys [:content]
    defstruct [
        id: "",
        line_number: 1,
        content: "",
        note: ""
    ]
    @type t :: %__MODULE__{id: String.t(), line_number: non_neg_integer, content: String.t(), note: String.t()}
  end

  # Creation from multi-line input
  def from_text(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, idx} ->
      %Line{
        id: generate_line_number(),  # UUID or other unique ID
        line_number: idx,
        content: line,
        note: ""
      }
    end)
  end

  def generate_line_number() do
    # Use UUID lib (added to deps)
    UUID.uuid4(:hex)
  end
end
