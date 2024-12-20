defmodule AnnotatorWeb.ExportHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use AnnotatorWeb, :html

  embed_templates "export_html/*"
end
