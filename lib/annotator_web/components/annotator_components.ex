defmodule AnnotatorWeb.AnnotatorComponents do
  use Phoenix.Component
  require Logger
  # use AnnotatorWeb, :html

  attr :chunk, :map, required: true

  def text_with_highlights(assigns) do
    Logger.info("text_with_highlights is being called; chunk is #{inspect(assigns.chunk)}")
    high_start = assigns.chunk.highlight_start
    high_end = assigns.chunk.highlight_end

    {start_pos, end_pos} = if high_start <= high_end do
      {high_start, high_end}
    else
      {high_end, high_start}
    end
    assigns = assign(assigns, start_pos: start_pos, end_pos: end_pos)

    ~H"""
    <%= String.slice(@chunk.text, 0, @start_pos) %>
    <span class="bg-yellow-200">
      <%= String.slice(@chunk.text, @start_pos, @end_pos - @start_pos) %>
    </span>
    <%= String.slice(@chunk.text, @end_pos..-1//1) %>
    """
  end
end
