defmodule Annotator.SharedHelpers do
  alias Annotator.Lines

  def get_chunk_groups(lines) do
    # returns a list of {chunk, lines} tuples
    chunks = get_collection_chunks(lines)
    # Create groups based on chunk_id
    line_groups = Enum.group_by(lines, & &1.chunk_id)
    # Map chunks to their lines, preserving chunk order
    chunks
    |> Enum.map(fn chunk ->
      {chunk, Map.get(line_groups, chunk.id, [])}
    end)
    |> Enum.sort_by(fn {_chunk, lines} ->
      case lines do
        [] -> 0
        [first | _] -> first.line_number
      end
    end)
  end

  defp get_collection_chunks(lines) do
    lines
    |> Enum.map(& &1.chunk)
    |> Enum.reject(&is_nil/1)
    # |> IO.inspect(label: "chunks before uniq_by")
    |> Enum.uniq_by(& &1.id)
  end
end
