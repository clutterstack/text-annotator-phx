defmodule Annotator.Repo.Migrations.InitialSchema do
  use Ecto.Migration

  def change do
    # Collections table - top level organization
    create table(:collections) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:collections, [:name])

    # Lines table - stores the actual content
    create table(:lines) do
      add :line_number, :integer, null: false
      # Use size: :infinity for long text
      add :content, :string, size: :infinity
      add :collection_id, references(:collections, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lines, [:collection_id, :line_number])
    create index(:lines, [:collection_id])

    # Chunks table - groups of lines that share a note
    create table(:chunks) do
      # Use size: :infinity for long text
      add :note, :string, size: :infinity
      add :collection_id, references(:collections, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chunks, [:collection_id])

    # Join table between chunks and lines
    create table(:chunk_lines) do
      add :chunk_id, references(:chunks, on_delete: :delete_all), null: false
      add :line_id, references(:lines, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Prevent the same line from being in multiple chunks
    create unique_index(:chunk_lines, [:line_id])
    create index(:chunk_lines, [:chunk_id])
  end
end
