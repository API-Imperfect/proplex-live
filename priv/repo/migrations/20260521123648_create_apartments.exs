defmodule Proplex.Repo.Migrations.CreateApartments do
  use Ecto.Migration

  def change do
    create table(:apartments) do
      add :building_name, :string, null: false
      add :unit_number, :string, null: false
      add :floor, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:apartments, [:building_name, :unit_number])
  end
end
