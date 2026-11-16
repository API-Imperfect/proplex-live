defmodule Proplex.Repo.Migrations.AddReportsAndModerationFlags do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :flagged_at, :utc_datetime, null: true

      add :suspended_at, :utc_datetime, null: true
    end

    create index(:users, [:flagged_at], where: "flagged_at IS NOT NULL")
    create index(:users, [:suspended_at], where: "suspended_at IS NOT NULL")

    create table(:reports) do
      add :reporter_id, references(:users, on_delete: :delete_all), null: false

      add :reported_id, references(:users, on_delete: :delete_all), null: false

      add :title, :string, null: false
      add :description, :text, null: false

      add :category, :string, null: false, default: "other"

      timestamps(type: :utc_datetime)
    end

    create constraint(:reports, :no_self_report, check: "reporter_id <> reported_id")

    create unique_index(:reports, [:reporter_id, :reported_id])

    create index(:reports, [:reported_id])
    create index(:reports, [:reporter_id])
  end
end
