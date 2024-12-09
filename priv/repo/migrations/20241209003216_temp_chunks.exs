defmodule Annotator.Repo.Migrations.TempChunks do
  use Ecto.Migration

  def change do
    # Add temporary field to chunks table
    alter table(:chunks) do
      add :temporary, :boolean, null: false, default: false
    end

    # Create a new lines table with the chunk_id
    create table(:new_lines) do
      add :line_number, :integer, null: false
      add :content, :text
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      add :chunk_id, references(:chunks, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    # Copy data from old lines to new lines
    execute """
    INSERT INTO new_lines (line_number, content, collection_id, chunk_id, inserted_at, updated_at)
    SELECT l.line_number, l.content, l.collection_id, c.id, l.inserted_at, l.updated_at
    FROM lines l
    CROSS JOIN (SELECT id FROM chunks LIMIT 1) c
    """

    # Drop old lines table
    drop table(:lines)

    # Rename new lines table to lines
    execute "ALTER TABLE new_lines RENAME TO lines"

    # Add unique index for collection_id + line_number
    create unique_index(:lines, [:collection_id, :line_number])
  end
end
