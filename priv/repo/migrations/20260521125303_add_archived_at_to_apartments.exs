defmodule Proplex.Repo.Migrations.AddArchivedAtToApartments do
  use Ecto.Migration

  def change do
    alter table(:apartments) do
      add :archived_at, :utc_datetime
    end
  end
end
