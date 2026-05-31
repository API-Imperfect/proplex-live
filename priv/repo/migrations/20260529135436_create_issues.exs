defmodule Proplex.Repo.Migrations.CreateIssues do
  use Ecto.Migration

  def change do
    create table(:issues) do
      add :title, :string, null: false
      add :description, :text, null: false
      add :priority, :string, null: false
      add :status, :string, null: false, default: "reported"
      add :resolved_on, :date
      add :deleted_at, :utc_datetime
      add :reporter_id, references(:users, on_delete: :restrict), null: false
      add :apartment_id, references(:apartments, on_delete: :restrict), null: false
      add :assigned_technician_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:issues, [:reporter_id])
    create index(:issues, [:assigned_technician_id])
    create index(:issues, [:apartment_id])
    create index(:issues, [:status])
    create index(:issues, [:priority])
  end
end
