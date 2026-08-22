defmodule Proplex.Repo.Migrations.AddPendingTenancies do
  use Ecto.Migration

  def change do

    create table(:pending_tenancies) do
      add :invite_email, :string, null: false

      add :apartment_id, references(:apartments, on_delete: :delete_all), null: false

      add :start_date, :date, null: false
      add :token_hash, :binary, null: false

      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pending_tenancies, [:apartment_id])

    create unique_index(:pending_tenancies, [:invite_email])

    create unique_index(:pending_tenancies, [:token_hash])

  end
end
