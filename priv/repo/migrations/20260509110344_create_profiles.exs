defmodule Proplex.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :first_name, :string
      add :middle_name, :string
      add :last_name, :string

      add :gender, :string

      add :occupation, :string, default: "none", null: false

      add :bio, :text
      add :phone_number, :string
      add :country, :string
      add :city, :string

      add :avatar_url, :string
      add :reputation, :integer, default: 100, null: false
      add :average_rating, :float, default: 0.0, null: false
      add :report_count, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:profiles, [:user_id])
  end
end
