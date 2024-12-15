defmodule Annotator.Repo.Migrations.RemoveLineNumberUniqueConstraint do
  use Ecto.Migration

  def up do
    # Create temporary table with desired schema
    create table(:lines_temp) do
      add :line_number, :integer
      add :content, :string
      add :collection_id, references(:collections, on_delete: :delete_all)
      add :chunk_id, references(:chunks, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    # Copy data from original table to temporary table
    execute """
    INSERT INTO lines_temp (id, line_number, content, collection_id, chunk_id, inserted_at, updated_at)
    SELECT id, line_number, content, collection_id, chunk_id, inserted_at, updated_at
    FROM lines;
    """

    # Drop original table
    drop table(:lines)

    # Create new table without the unique constraint
    create table(:lines) do
      add :line_number, :integer
      add :content, :string
      add :collection_id, references(:collections, on_delete: :delete_all)
      add :chunk_id, references(:chunks, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    # Copy data back from temporary table
    execute """
    INSERT INTO lines (id, line_number, content, collection_id, chunk_id, inserted_at, updated_at)
    SELECT id, line_number, content, collection_id, chunk_id, inserted_at, updated_at
    FROM lines_temp;
    """

    # Drop temporary table
    drop table(:lines_temp)

    # Create index on collection_id and line_number (non-unique)
    create index(:lines, [:collection_id, :line_number])
  end

  def down do
    # If you need to roll back, recreate the unique constraint
    drop index(:lines, [:collection_id, :line_number])
    create unique_index(:lines, [:collection_id, :line_number])
  end
end
