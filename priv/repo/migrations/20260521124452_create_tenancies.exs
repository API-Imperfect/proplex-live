defmodule Proplex.Repo.Migrations.CreateTenancies do
  use Ecto.Migration

  def change do
    create table(:tenancies) do
      add :apartment_id, references(:apartments, on_delete: :delete_all), null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :start_date, :date, null: false
      add :end_date, :date

      timestamps(type: :utc_datetime)
    end

    create index(:tenancies, [:user_id])
    create index(:tenancies, [:apartment_id])

    create unique_index(:tenancies, [:apartment_id],
             name: :tenancies_active_apartment_index,
             where: "end_date IS NULL"
           )

    create unique_index(:tenancies, [:user_id],
             name: :tenancies_active_user_index,
             where: "end_date IS NULL"
           )
  end
end
