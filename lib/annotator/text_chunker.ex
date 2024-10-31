defmodule Annotator.TextChunker do

  @moduledoc """
  Splits text chunks based on position and length, respecting line boundaries.
  Returns both the chunks and the new position within the relevant chunk.
  Claude wrote the initial version of this.
  """

  require Logger

  @type chunk_result :: {[String.t()], non_neg_integer()}

  @doc """
  Split a text chunk based on position and length, respecting line boundaries.

  Returns a tuple containing:
  - List of 1-3 strings representing the split chunks
  - The new position within the relevant chunk where the original position maps to

  ## Parameters
    - text: The input text to split
    - position: Starting position for the split
    - length: Length of the section to split out

  ## Examples
      iex> text = "Line 1\\nLine 2\\nLine 3"
      iex> TextChunker.split_text_chunk(text, 0, 0)
      {["Line 1\\nLine 2\\nLine 3"], 0}

      iex> text = "Line 1\\nLine 2\\nLine 3"
      iex> TextChunker.split_text_chunk(text, 0, 7)
      {["Line 1\\n", "Line 2\\nLine 3"], 0}

      iex> text = "Line 1\\nLine 2\\nLine 3"
      iex> TextChunker.split_text_chunk(text, 8, 7)
      {["Line 1", "\\nLine 2\\n", "Line 3"], 1}
  """
  @spec split_text_chunk(String.t(), non_neg_integer(), non_neg_integer()) :: chunk_result
  def split_text_chunk("", position, _length), do: {[""], position}
  def split_text_chunk(text, position, 0) when position in [0, byte_size(text)], do: {[text], position}

  def split_text_chunk(text, position, length) do
    # Find all newline positions, including virtual ones at start and end
    newline_positions =
      [-1] ++
      (text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.filter(fn {char, _idx} -> char == "\n" end)
      |> Enum.map(fn {_char, idx} -> idx end)) ++
      [String.length(text)]

    cond do
      # Split from start
      position == 0 ->
        split_from_start(text, length, newline_positions)

      # Split from end
      position == String.length(text) - length ->
        split_from_end(text, length, newline_positions)

      # Split in middle
      true ->
        Logger.info("split_text_chunk: text, position, length, newline_positions: #{inspect [text, position, length, newline_positions]}")
        Logger.info("string length: #{String.length(text)}")
        split_in_middle(text, position, length, newline_positions)
    end
  end

  defp split_from_start(text, length, newline_positions) do
    end_line_end =
      newline_positions
      |> Enum.find(fn pos -> pos >= length end)
    # Position stays at 0 in first chunk
    [
      {String.slice(text, 0..end_line_end), 0},
      {String.slice(text, (end_line_end + 1)..-1//1), nil} # the //1 is to avoid negative steps; elixir gave me a warning about that
    ]
  end

  defp split_from_end(text, _length, newline_positions) do
    text_length = String.length(text)
    start_line_start =
      newline_positions
      |> Enum.reverse()
      |> Enum.find(fn pos -> pos < text_length end)
      |> Kernel.+(1)

    # Position will be at the start of the second chunk
    [
      {String.slice(text, 0..(start_line_start - 2)), nil},
      {String.slice(text, (start_line_start - 1)..-1//1), 0}
    ]
  end

  defp split_in_middle(text, position, length, newline_positions) do
    # Find line boundaries for start position
    start_line_start =
      newline_positions
      |> Enum.filter(&(&1 < position))
      |> Enum.max()
      |> Kernel.+(1)

    # Find line boundaries for end position
    end_pos = position + length
    end_line_end =
      newline_positions
      |> Enum.find(fn pos -> pos >= end_pos end)
      # |> IO.inspect(label: "END_LINE_END")

    # Calculate new position within middle chunk
    new_position = position - (start_line_start - 1)

    [
      {String.slice(text, 0..(start_line_start - 2)//1), nil},
      {String.slice(text, (start_line_start - 1)..end_line_end), new_position},
      {String.slice(text, (end_line_end + 1)..-1//1), nil}
    ]

  end
end
