defmodule Annotator.Repo.Migrations.SimplifyChunksSchema do
  use Ecto.Migration

  def up do
    # First create the new chunks table structure
    create table(:chunks_new) do
      add :note, :string, default: ""
      add :start_line, :integer, null: false
      add :end_line, :integer, null: false
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    # Add check constraint separately
    execute("CREATE INDEX chunks_new_end_line_check ON chunks_new(end_line >= start_line)")

    # Add indexes for the new chunks table
    create index(:chunks_new, [:collection_id])
    create index(:chunks_new, [:start_line, :end_line])

    # Migrate data from old structure to new chunks table
    execute """
    INSERT INTO chunks_new (note, start_line, end_line, collection_id, inserted_at, updated_at)
    SELECT
      c.note,
      MIN(l.line_number) as start_line,
      MAX(l.line_number) as end_line,
      c.collection_id,
      c.inserted_at,
      c.updated_at
    FROM chunks c
    JOIN chunk_lines cl ON cl.chunk_id = c.id
    JOIN lines l ON l.id = cl.line_id
    GROUP BY c.id, c.note, c.collection_id, c.inserted_at, c.updated_at
    """

    # Create new lines table with chunk_id
    create table(:lines_new) do
      add :line_number, :integer, null: false
      add :content, :string
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      add :chunk_id, references(:chunks_new, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime)
    end

    # Copy existing data and set chunk_id
    execute """
    INSERT INTO lines_new (id, line_number, content, collection_id, chunk_id, inserted_at, updated_at)
    SELECT
      l.id,
      l.line_number,
      l.content,
      l.collection_id,
      c.id as chunk_id,
      l.inserted_at,
      l.updated_at
    FROM lines l
    JOIN chunk_lines cl ON cl.line_id = l.id
    JOIN chunks_new c ON c.start_line <= l.line_number
      AND c.end_line >= l.line_number
      AND c.collection_id = l.collection_id
    """

    # Drop old tables
    drop table(:chunk_lines)
    drop table(:chunks)
    drop table(:lines)

    # Rename new tables to final names
    rename table(:chunks_new), to: table(:chunks)
    rename table(:lines_new), to: table(:lines)

    # Add indexes
    create index(:chunks, [:collection_id])
    create index(:chunks, [:start_line, :end_line])
    create index(:lines, [:collection_id])
    create index(:lines, [:chunk_id])
    create unique_index(:lines, [:collection_id, :line_number])
  end

  def down do
    # Create original tables with their original structure
    create table(:chunks) do
      add :note, :string, default: ""
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create table(:chunk_lines) do
      add :chunk_id, references(:chunks, on_delete: :delete_all), null: false
      add :line_id, references(:lines, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create table(:lines_old) do
      add :line_number, :integer, null: false
      add :content, :string
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    # Copy data back to original structure
    execute """
    INSERT INTO chunks (note, collection_id, inserted_at, updated_at)
    SELECT note, collection_id, inserted_at, updated_at
    FROM chunks_new
    """

    execute """
    INSERT INTO lines_old (id, line_number, content, collection_id, inserted_at, updated_at)
    SELECT id, line_number, content, collection_id, inserted_at, updated_at
    FROM lines
    """

    execute """
    INSERT INTO chunk_lines (chunk_id, line_id, inserted_at, updated_at)
    SELECT c.id, l.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM chunks c
    JOIN chunks_new cn ON cn.collection_id = c.collection_id AND cn.note = c.note
    JOIN lines l ON l.chunk_id = cn.id
    """

    # Drop new tables
    drop table(:lines)
    drop table(:chunks_new)

    # Rename old lines table
    rename table(:lines_old), to: table(:lines)

    # Recreate original indexes
    create index(:chunks, [:collection_id])
    create index(:lines, [:collection_id])
    create unique_index(:lines, [:collection_id, :line_number])
    create unique_index(:chunk_lines, [:chunk_id, :line_id])
  end
end
