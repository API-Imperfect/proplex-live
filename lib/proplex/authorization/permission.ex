defmodule Proplex.Authorization.Permission do
  use Ecto.Schema

  import Ecto.Changeset

  schema "permissions" do
    field :resource, :string
    field :action, :string
    field :description, :string

    many_to_many :roles, Proplex.Authorization.Role, join_through: "role_permissions"

    timestamps(type: :utc_datetime)
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:resource, :action, :description])
    |> validate_required([:resource, :action])
    |> unique_constraint([:resource, :action])
  end
end
