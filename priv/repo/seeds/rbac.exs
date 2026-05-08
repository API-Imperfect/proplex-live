# RBAC seeds — permissions, roles, and role→permission mappings.
# Loaded by priv/repo/seeds.exs.
#
# This file is a standalone script: it has its own aliases, its own
# helpers, and doesn't leak anything to the orchestrator. Run via:
#
#     mix run priv/repo/seeds.exs   # executes this file + others
#
# Or in isolation:
#
#     mix run priv/repo/seeds/rbac.exs

alias Proplex.Repo
alias Proplex.Authorization.{Role, Permission}

# ── Permissions ──────────────────────────────────────────────────
# Each permission is a resource + action pair.
# Uses on_conflict: :nothing so seeds are idempotent (safe to re-run).

permissions =
  [
    # Issues
    {"issues", "create", "Create new maintenance issues"},
    {"issues", "view_own", "View own reported issues"},
    {"issues", "view_assigned", "View issues assigned to you"},
    {"issues", "view_all", "View all issues"},
    {"issues", "update_status", "Update issue status"},
    {"issues", "assign", "Assign issues to technicians"},
    {"issues", "delete", "Delete issues"},

    # Posts
    {"posts", "create", "Create community posts"},
    {"posts", "view", "View community posts"},
    {"posts", "delete_any", "Delete any post"},

    # Technicians
    {"technicians", "rate", "Rate technicians"},

    # Profiles
    {"profiles", "view", "View user profiles"},
    {"profiles", "edit_own", "Edit own profile"},
    {"profiles", "edit_any", "Edit any profile"},

    # Apartments
    # NOTE: "apartments:create_own" is obsolete — under the revised Feature 3
    # (admin-managed apartments + tenancies), tenants no longer create
    # apartments. The permission row stays in the DB for historical
    # reasons but is no longer assigned to the tenant role below.
    {"apartments", "create_own", "Register own apartment (obsolete — see landlord.md)"},
    {"apartments", "view_own", "View own apartment"},
    {"apartments", "view_all", "View all apartments"},
    {"apartments", "manage", "Create, edit, delete apartments and tenancies"},

    # Users
    {"users", "manage", "Manage user accounts"},
    {"users", "create_technician", "Create technician accounts"},

    # Reports
    {"reports", "create", "Report another user"},
    {"reports", "view_own", "View own filed reports"},
    {"reports", "view_all", "View all reports"},
    {"reports", "manage", "Manage reports (reactivate users, reset counts)"},

    # Roles
    {"roles", "manage", "Manage roles and permissions"}
  ]
  |> Enum.map(fn {resource, action, description} ->
    now = DateTime.utc_now(:second)

    %{
      resource: resource,
      action: action,
      description: description,
      inserted_at: now,
      updated_at: now
    }
  end)

Repo.insert_all(Permission, permissions, on_conflict: :nothing)

# reload all permissions from the DB so we can reference them by resource:action
all_permissions =
  Repo.all(Permission)
  |> Enum.map(fn p -> {"#{p.resource}:#{p.action}", p.id} end)
  |> Map.new()

# ── Roles ────────────────────────────────────────────────────────
# Default global roles (property_id = nil).
# Uses find-or-create pattern because the partial unique indexes
# (NULL-safe) don't work with on_conflict + conflict_target.

find_or_create_role = fn name, description ->
  import Ecto.Query

  # can't use Repo.get_by with nil — Ecto forbids nil comparisons
  # use is_nil/1 in a query instead
  existing =
    Repo.one(
      from r in Role,
        where: r.name == ^name and is_nil(r.property_id)
    )

  case existing do
    %Role{} = role ->
      role

    nil ->
      Repo.insert!(%Role{
        name: name,
        description: description,
        property_id: nil
      })
  end
end

tenant_role = find_or_create_role.("tenant", "Default role for self-registered users")
technician_role = find_or_create_role.("technician", "Maintenance technician — assigned by admin")
admin_role = find_or_create_role.("admin", "Full platform management")

# ── Role → Permission mappings ───────────────────────────────────

# helper to link a role to a list of "resource:action" keys
assign_permissions = fn role, permission_keys ->
  rows =
    permission_keys
    |> Enum.map(fn key ->
      %{role_id: role.id, permission_id: Map.fetch!(all_permissions, key)}
    end)

  Repo.insert_all("role_permissions", rows, on_conflict: :nothing)
end

# only assign if the role was actually inserted (id is present)
if tenant_role.id do
  assign_permissions.(tenant_role, [
    "issues:create", "issues:view_own",
    "posts:create", "posts:view",
    "technicians:rate",
    "profiles:view", "profiles:edit_own",
    # NOTE: "apartments:create_own" intentionally omitted — tenants no longer
    # create apartments. Admin creates units; admin assigns tenancies.
    "apartments:view_own",
    "reports:create", "reports:view_own"
  ])

  # Clean up obsolete assignments that earlier seed runs may have left behind.
  # Seeds represent DESIRED state, so we explicitly remove permissions the
  # tenant role should no longer have. Idempotent — a no-op on the second run.
  import Ecto.Query

  revoked_permission_keys = ["apartments:create_own"]
  revoked_permission_ids = Enum.map(revoked_permission_keys, &Map.get(all_permissions, &1))

  Repo.delete_all(
    from rp in "role_permissions",
      where: rp.role_id == ^tenant_role.id and rp.permission_id in ^revoked_permission_ids
  )
end

if technician_role.id do
  assign_permissions.(technician_role, [
    "issues:view_assigned", "issues:update_status",
    "profiles:view", "profiles:edit_own",
    "posts:view"
  ])
end

if admin_role.id do
  # admin gets every permission
  assign_permissions.(admin_role, Map.keys(all_permissions))
end
