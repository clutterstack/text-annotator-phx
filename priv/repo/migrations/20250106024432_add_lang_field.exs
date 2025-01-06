defmodule Annotator.Repo.Migrations.AddLangField do
  use Ecto.Migration

  def change do
    alter table(:collections) do
      add :lang, :string
    end
  end
end
