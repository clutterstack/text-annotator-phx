defmodule Annotator.LinesTest do
  use Annotator.DataCase
  alias Annotator.Lines
  alias Annotator.Lines.Collection

  describe "collections" do
    @valid_attrs %{name: "test collection"}
    @invalid_attrs %{name: nil}

    test "create_collection/1 with valid data creates a collection" do
      assert {:ok, %Collection{} = collection} = Lines.create_collection(@valid_attrs)
      assert collection.name == "test collection"
    end

    test "create_collection/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Lines.create_collection(@invalid_attrs)
    end

    test "get_collection_with_assocs/1 returns collection with preloaded associations" do
      {:ok, collection} = Lines.create_collection(@valid_attrs)
      # Create an initial chunk and line
      Lines.append_chunk(collection.id)

      loaded_collection = Lines.get_collection_with_assocs(collection.id)
      assert loaded_collection.id == collection.id
      assert loaded_collection.name == collection.name
      assert length(loaded_collection.lines) == 1
      assert hd(loaded_collection.lines).chunk != nil
    end
  end
end
