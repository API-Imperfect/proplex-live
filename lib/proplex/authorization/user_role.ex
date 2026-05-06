defmodule Proplex.Authorization.UserRole do
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_roles" do
    belongs_to :user, Proplex.Accounts.User
    belongs_to :role, Proplex.Authorization.Role

    field :property_id, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :property_id])
    |> validate_required([:user_id, :role_id])
    |> unique_constraint([:user_id, :role_id, :property_id],
      name: :user_roles_user_role_property_index
    )
    |> unique_constraint([:user_id, :role_id],
      name: :user_roles_user_role_global_index
    )
  end
end
