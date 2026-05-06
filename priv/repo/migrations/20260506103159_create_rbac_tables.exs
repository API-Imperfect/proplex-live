defmodule Proplex.Repo.Migrations.CreateRbacTables do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :description, :string
      add :property_id, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:name, :property_id],
             name: :roles_name_property_id_index,
             where: "property_id IS NOT NULL"
           )

    create unique_index(:roles, [:name],
             name: :roles_name_global_index,
             where: "property_id IS NULL"
           )

    create table(:permissions) do
      add :resource, :string, null: false
      add :action, :string, null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:permissions, [:resource, :action])

    create table(:role_permissions, primary_key: false) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
    end

    create unique_index(:role_permissions, [:role_id, :permission_id])
    create index(:role_permissions, [:permission_id])

    create table(:user_roles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role_id, references(:roles, on_delete: :delete_all), null: false

      add :property_id, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_roles, [:user_id, :role_id, :property_id],
             name: :user_roles_user_role_property_index,
             where: "property_id IS NOT NULL"
           )

    create unique_index(:user_roles, [:user_id, :role_id],
             name: :user_roles_user_role_global_index,
             where: "property_id IS NULL"
           )

    create index(:user_roles, [:user_id])
    create index(:user_roles, [:role_id])
  end
end
