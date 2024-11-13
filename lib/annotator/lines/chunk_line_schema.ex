defmodule Annotator.Lines.ChunkLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chunk_lines" do
    belongs_to :chunk, Annotator.Lines.Chunk
    belongs_to :line, Annotator.Lines.Line
    timestamps(type: :utc_datetime)
  end

  def changeset(chunk_line, attrs) do
    chunk_line
    |> cast(attrs, [:chunk_id, :line_id])
    |> validate_required([:chunk_id, :line_id])
    |> unique_constraint([:chunk_id, :line_id])
  end
end
