defmodule Proplex.Repo.Migrations.BackfillTenantRoleForExistingUsers do
  use Ecto.Migration

  import Ecto.Query

  def up do
    tenant_role_id =
      case repo().query!(
             "SELECT id FROM roles WHERE name = 'tenant' AND property_id IS NULL LIMIT 1"
           ) do
        %{rows: [[id]]} -> id
        _ -> nil
      end

    if tenant_role_id do
      now =
        DateTime.utc_now()
        |> DateTime.truncate(:second)
        |> DateTime.to_naive()

      repo().query!(
        """
        INSERT INTO user_roles (user_id, role_id, property_id, inserted_at, updated_at)
        SELECT u.id, $1, NULL, $2, $2
        FROM users u
        WHERE NOT EXISTS(
         SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id
        )
        """,
        [tenant_role_id, now]
      )
    end
  end

  def down do
    :ok
  end
end
