defmodule Annotator.Repo.Migrations.AddCollectionsAndLinesTables do
  use Ecto.Migration

  def change do
    create table(:collections) do
      add :name, :string, null: false
      add :lines, {:array, :map}, default: []
      timestamps(type: :utc_datetime)
    end
    create unique_index(:collections, [:name])

    create table(:lines) do
      add :collection_id, references(:collections, on_delete: :delete_all), null: false
      add :line_number, :integer, null: false
      add :content, :string, default: ""
      add :note, :string, default: ""
      timestamps(type: :utc_datetime)
    end

    create index(:lines, [:collection_id])
    create unique_index(:lines, [:collection_id, :line_number])
  end
end
