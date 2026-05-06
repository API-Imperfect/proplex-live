defmodule Proplex.Authorization.Role do
  use Ecto.Schema

  import Ecto.Changeset

  schema "roles" do
    field :name, :string
    field :description, :string
    field :property_id, :integer

    many_to_many :permissions, Proplex.Authorization.Permission, join_through: "role_permissions"

    has_many :user_roles, Proplex.Authorization.UserRole

    timestamps(type: :utc_datetime)
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description, :property_id])
    |> validate_required([:name])
    |> unique_constraint([:name, :property_id], name: :roles_name_property_id_index)
    |> unique_constraint([:name], name: :roles_name_global_index)
  end
end
