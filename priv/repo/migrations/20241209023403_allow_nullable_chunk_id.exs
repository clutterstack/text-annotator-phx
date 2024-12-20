defmodule Annotator.Repo.Migrations.AllowNullableChunkId do
  use Ecto.Migration

  def change do
    # Create new table with desired schema
    create table(:lines_new) do
      add :line_number, :integer, null: false
      add :content, :string
      add :collection_id, references(:collections), null: false
      # This is now nullable
      add :chunk_id, references(:chunks), null: true
      timestamps(type: :utc_datetime)
    end

    # Copy data from old to new
    execute """
    INSERT INTO lines_new (id, line_number, content, collection_id, chunk_id, inserted_at, updated_at)
    SELECT id, line_number, content, collection_id, chunk_id, inserted_at, updated_at
    FROM lines;
    """

    # Drop old table
    drop table(:lines)

    # Rename new table to old name
    rename table(:lines_new), to: table(:lines)

    # Recreate indices/constraints that were on the original table
    create unique_index(:lines, [:collection_id, :line_number])
  end
end
