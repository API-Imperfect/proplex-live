defmodule Proplex.Authorization do
  import Ecto.Query
  require Logger

  alias Proplex.Repo

  alias Proplex.Authorization.{Role, Permission, UserRole}

  def can?(user, action, resource, opts \\ []) do
    action_str = to_string(action)
    resource_str = to_string(resource)

    property_id = Keyword.get(opts, :property_id)

    query =
      from ur in UserRole,
        join: r in assoc(ur, :role),
        join: rp in "role_permissions",
        on: rp.role_id == r.id,
        join: p in Permission,
        on: p.id == rp.permission_id,
        where: ur.user_id == ^user.id,
        where: p.resource == ^resource_str,
        where: p.action == ^action_str

    query =
      if property_id do
        from [ur, r, rp, p] in query,
          where: ur.property_id == ^property_id or is_nil(ur.property_id)
      else
        query
      end

    Repo.exists?(query)
  end

  def revoke_role(user, role_name, opts \\ []) do
    property_id = Keyword.get(opts, :property_id)

    with %Role{} = role <- get_role_by_name(role_name) do
      query =
        from ur in UserRole,
          where: ur.user_id == ^user.id,
          where: ur.role_id == ^role.id

      query =
        if property_id do
          from ur in query, where: ur.property_id == ^property_id
        else
          from ur in query, where: is_nil(ur.property_id)
        end

      {count, _} = Repo.delete_all(query)

      if count > 0 do
        Logger.info("Role revoked",
          event: :role_revoked,
          user_id: user.id,
          role: to_string(role_name),
          property_id: property_id
        )

        :ok
      else
        {:error, :not_found}
      end
    else
      nil -> {:error, :role_not_found}
    end
  end

  def list_user_roles(user) do
    from(ur in UserRole,
      join: r in assoc(ur, :role),
      where: ur.user_id == ^user.id,
      select: %{name: r.name, property_id: ur.property_id}
    )
    |> Repo.all()
  end

  def assign_role(user, role_name, opts \\ []) do
    property_id = Keyword.get(opts, :property_id)

    with %Role{} = role <- get_role_by_name(role_name),
         {:ok, user_role} <-
           %UserRole{}
           |> UserRole.changeset(%{
             user_id: user.id,
             role_id: role.id,
             property_id: property_id
           })
           |> Repo.insert() do
      Logger.info("Role assigned",
        event: :role_assigned,
        user_id: user.id,
        role: to_string(role_name),
        property_id: property_id
      )

      {:ok, user_role}
    else
      nil -> {:error, :role_not_found}
      {:error, _changeset} = err -> err
    end
  end

  def has_role?(user, role_name) do
    from(ur in UserRole,
      join: r in assoc(ur, :role),
      where: ur.user_id == ^user.id,
      where: r.name == ^to_string(role_name)
    )
    |> Repo.exists?()
  end

  def list_users_with_role(role_name) do
    technician_ids =
      from ur in UserRole,
        join: r in assoc(ur, :role),
        where: r.name == ^to_string(role_name),
        select: ur.user_id

    from(u in Proplex.Accounts.User,
      where: u.id in subquery(technician_ids),
      order_by: u.username
    )
    |> Repo.all()
  end

  def get_role_by_name(name) do
    Repo.get_by(Role, name: to_string(name))
  end

  def list_roles do
    Repo.all(from r in Role, order_by: r.name, preload: :permissions)
  end

  def list_permissions do
    Repo.all(from p in Permission, order_by: [p.resource, p.action])
  end
end
