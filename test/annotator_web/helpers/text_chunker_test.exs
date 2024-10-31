defmodule TextChunkerTest do
  use ExUnit.Case
  doctest TextChunker

  @test_text """
  Line 1
  Line 2
  Line 3
  Line 4
  Line 5
  """

  test "empty text returns empty string in list with same position" do
    assert TextChunker.split_text_chunk("", 5, 0) == {[""], 5}
  end

  test "no split when position is start and length is 0" do
    assert TextChunker.split_text_chunk(@test_text, 0, 0) == {@test_text |> List.wrap(), 0}
  end

  test "no split when position is end and length is 0" do
    position = String.length(@test_text)
    assert TextChunker.split_text_chunk(@test_text, position, 0) == {@test_text |> List.wrap(), position}
  end

  test "splits into two chunks from start with position" do
    {[chunk1, chunk2], position} = TextChunker.split_text_chunk(@test_text, 0, 7)
    assert chunk1 == "Line 1\n"
    assert chunk2 == "Line 2\nLine 3\nLine 4\nLine 5\n"
    assert position == 0
  end

  test "splits into two chunks from end with position" do
    text_length = String.length(@test_text)
    {[chunk1, chunk2], position} = TextChunker.split_text_chunk(@test_text, text_length, 5)
    assert chunk1 == "Line 1\nLine 2\nLine 3\nLine 4"
    assert chunk2 == "\nLine 5\n"
    assert position == 0
  end

  test "splits into three chunks from middle with position" do
    {[chunk1, chunk2, chunk3], position} = TextChunker.split_text_chunk(@test_text, 8, 12)
    assert chunk1 == "Line 1"
    assert chunk2 == "\nLine 2\n"
    assert chunk3 == "Line 3\nLine 4\nLine 5\n"
    assert position == 1  # Position 8 in original becomes position 1 in middle chunk
  end
end
