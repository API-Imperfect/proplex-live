# User seeds — fixed admin + technician accounts for local dev and
# browser testing. Loaded by priv/repo/seeds.exs AFTER rbac.exs (so the
# roles exist) and AFTER apartments.exs (no ordering dependency, but
# keeps "inventory before people" mental model).
#
# Run via:
#
#     mix run priv/repo/seeds.exs          # full stack
#     mix run priv/repo/seeds/users.exs    # just this file
#
# ── Seeded accounts ──────────────────────────────────────────────
#
#   admin@proplex.local       → admin role      (full management)
#   technician@proplex.local  → technician role (gets assignments)
#
# Shared password: "proplex-dev-pass" (meets the 12-char min in
# User.validate_password/2 — no other character-class rules today).
#
# Both accounts are PRE-CONFIRMED so you can log in immediately with
# email + password — no magic-link roundtrip needed on localhost.
#
# Tenant accounts aren't seeded: register one via the UI to exercise
# the signup flow end-to-end. The registration default role is
# "tenant", which is exactly what self-registered users get.
#
# ── Finish the 4F test setup from IEx ───────────────────────────
#
# After seeding + registering a tenant via the browser:
#
#     # 1. Give the tenant an apartment (admin-initiated tenancy)
#     user = Proplex.Repo.get_by!(Proplex.Accounts.User, email: "tenant@example.com")
#     apt  = Proplex.Repo.get_by!(Proplex.Apartments.Apartment,
#              building_name: "North Tower", unit_number: "101")
#     Proplex.Apartments.start_tenancy(%{
#       user_id: user.id,
#       apartment_id: apt.id,
#       start_date: Date.utc_today()
#     })
#
#     # 2. Tenant logs in and reports an issue via /issues/new
#
#     # 3. Assign that issue to the technician
#     tech  = Proplex.Repo.get_by!(Proplex.Accounts.User, email: "technician@proplex.local")
#     issue = Proplex.Repo.get_by!(Proplex.Issues.Issue, title: "Leaky faucet in kitchen")
#     Proplex.Issues.assign_technician(issue, tech.id)
#
# Once the admin UI (4G) lands, steps 1 and 3 become point-and-click.

alias Proplex.Repo
alias Proplex.Accounts
alias Proplex.Accounts.User
alias Proplex.Authorization

# Shared dev password — must be >= 12 chars per User.validate_password/2.
# Kept in the file (not env) because this is dev-only seed data; no
# production user ever sees this.
seed_password = "proplex-dev-pass"

# Find an existing user by email, or register a fresh one and swap their
# default "tenant" role for the target role. Pre-confirms new users so
# they can authenticate with email + password on first attempt.
#
# Idempotent: re-running this seed is a no-op. If the user exists we
# just re-assert the role assignment (duplicate grants are swallowed
# by the unique constraint inside Authorization.assign_role/3).
ensure_user = fn email, username, role ->
  case Repo.get_by(User, email: email) do
    # ── Existing user path ────────────────────────────────────────
    %User{} = user ->
      # Re-assert the role. If it's already assigned, the DB unique
      # index on (user_id, role_id, property_id) raises and
      # assign_role returns {:error, changeset} — harmless here.
      _ = Authorization.assign_role(user, role)
      user

    # ── New user path ─────────────────────────────────────────────
    nil ->
      # register_user runs the canonical Multi: user → profile → role.
      # It always assigns the "tenant" role — we'll swap that below
      # for admin/technician accounts.
      {:ok, user} =
        Accounts.register_user(%{
          email: email,
          username: username,
          password: seed_password
        })

      # Stamp confirmed_at so email+password login works without the
      # magic-link confirmation roundtrip. On localhost we don't have
      # a real mailbox anyway.
      {:ok, user} =
        user
        |> User.confirm_changeset()
        |> Repo.update()

      # Swap the default tenant role for the target role — unless the
      # target IS "tenant" (then register_user already did the right
      # thing and we skip the churn).
      if role != "tenant" do
        # revoke_role returns :ok or {:error, :not_found}; either way
        # we proceed. Match loosely to keep the seed resilient.
        _ = Authorization.revoke_role(user, "tenant")
        {:ok, _} = Authorization.assign_role(user, role)
      end

      user
  end
end

IO.puts("  → admin@proplex.local (admin role)")
ensure_user.("admin@proplex.local", "admin", "admin")

IO.puts("  → technician@proplex.local (technician role)")
ensure_user.("technician@proplex.local", "technician", "technician")
