# ── Demo seed — bulk data for exercising pagination / filters ──
#
# Creates ~30 tenants, ~30 apartments, ~20 tenancies, ~30 issues, so
# every paginated admin list overflows its 20-row page and shows
# "Load more". Use for manual browser testing or demos.
#
# Run standalone:
#
#     mix run priv/repo/seeds/demo.exs
#
# NOT invoked by priv/repo/seeds.exs (the orchestrator) — demo data
# shouldn't auto-run on `mix ecto.reset`. If you want a clean slate
# with just the baseline:
#
#     mix ecto.reset                               # only rbac + apartments + users
#     mix run priv/repo/seeds/demo.exs             # THEN add demo data
#
# Idempotency:
#   * Tenants   — find-or-create by email, profile fields re-asserted.
#   * Apartments — find-or-create by (building_name, unit_number).
#   * Tenancies — skipped if the tenant already has an active tenancy.
#   * Issues    — NOT idempotent (each run adds ~30 more to the pile).
#                 Fine for a demo seed — more issues just means more
#                 pagination to test. If you want a known total,
#                 `mix ecto.reset` first to start from the baseline.
#
# Depends on rbac.exs + apartments.exs + users.exs having run first
# (needs roles + the seeded admin/technician to exist). `mix ecto.reset`
# handles that before this script runs.

alias Proplex.Repo
alias Proplex.Accounts
alias Proplex.Accounts.{User, Profile}
alias Proplex.Apartments
alias Proplex.Apartments.Apartment
alias Proplex.Issues
alias Proplex.Authorization

IO.puts("== Demo seed: bulk tenants + apartments + tenancies + issues ==")

# ── Pre-flight checks ──────────────────────────────────────────

# Make sure rbac + users seeds have already run — without those, user
# registration fails (no "tenant" role) and tenancies fail (no seeded
# technician to assign to).
unless Authorization.get_role_by_name("tenant") do
  IO.puts("\n❌ RBAC not seeded. Run `mix run priv/repo/seeds/rbac.exs` first.")
  System.halt(1)
end

technician = Accounts.get_user_by_email("technician@proplex.local")

unless technician do
  IO.puts("\n❌ technician@proplex.local not found. Run `mix run priv/repo/seeds/users.exs` first.")
  System.halt(1)
end

# ── Tenants ──────────────────────────────────────────────────

# Shared dev password — matches admin/technician in users.exs so every
# seeded account uses the same credentials. Easier for manual testing
# than juggling two passwords.
demo_password = "proplex-dev-pass"

# First names + last names rotate through these lists — deterministic
# and realistic enough for a demo without hitting a fake-name library.
first_names =
  ~w(Alice Bob Carol Dan Eve Frank Grace Henry Iris Jack Kate Leo Maya Noah
     Olivia Peter Quinn Ruth Sam Tina Uma Victor Wendy Xavier Yasmin
     Zara Aaron Beth Chris Dina)

last_names =
  ~w(Anderson Brown Carter Davis Evans Foster Green Hill Ingram Jones
     Khan Lopez Miller Nakamura Owen Patel Quinn Reyes Smith Thompson
     Umenyi Valdez Walsh Xu Yamada Zhang Abrams Bates Cohen Delgado)

# Build all 30 (name, email, phone) tuples up front so each tenant
# gets a deterministic placement across runs.
tenant_data =
  for i <- 1..30 do
    first = Enum.at(first_names, rem(i - 1, length(first_names)))
    last = Enum.at(last_names, rem(i - 1, length(last_names)))
    email = "tenant#{i}@proplex.local"
    username = "tenant-#{i}"
    phone = "555-#{String.pad_leading(to_string(100 + i), 4, "0")}"
    {first, last, email, username, phone}
  end

IO.puts("  Creating (or skipping existing) tenant users...")

tenants =
  for {first, last, email, username, phone} <- tenant_data do
    # Find-or-create the user.
    user =
      case Accounts.get_user_by_email(email) do
        %User{} = existing ->
          existing

        nil ->
          {:ok, user} =
            Accounts.register_user(%{
              "email" => email,
              "username" => username,
              "password" => demo_password
            })

          # Stamp confirmed_at so they can log in with password directly
          # (handy for smoke-testing the tenant view).
          {:ok, user} =
            user
            |> User.confirm_changeset()
            |> Repo.update()

          user
      end

    # Ensure the profile is filled, whether the user was just created
    # OR already existed from a prior run. Previously-seeded tenants
    # without profile fields would fail the "report an issue" gate,
    # so every run re-asserts the fields. update_user_profile is
    # effectively idempotent for our purposes — it rewrites the same
    # values on re-run.
    user = Repo.preload(user, :profile, force: true)

    user =
      case user.profile do
        %Profile{first_name: ^first, last_name: ^last, phone_number: ^phone} ->
          # Already correct — skip the DB write.
          user

        %Profile{} = profile ->
          {:ok, _} =
            Accounts.update_user_profile(profile, %{
              "first_name" => first,
              "last_name" => last,
              "phone_number" => phone
            })

          # Re-preload so the returned user carries the fresh profile.
          # Downstream code (Issues.report_issue → missing_profile_fields_for_reporting)
          # calls Repo.preload without force: true, which is a no-op when the
          # association is already loaded — leaving us reading the stale pre-update
          # struct and wrongly concluding the profile is incomplete.
          Repo.preload(user, :profile, force: true)
      end

    user
  end

IO.puts("  #{length(tenants)} tenants ready.")

# ── Apartments ───────────────────────────────────────────────

# Four buildings × up to 8 units each = 32 apartments. Varied floors
# for realism and to exercise the filter bar.
apartment_data =
  for building <- ["North Tower", "South Block", "East Wing", "West Annex"],
      floor <- [1, 2, 3],
      unit_number_base <- [1, 2, 3],
      # Skip one combo per building so we don't hit 36 (keep things tidy).
      not (building == "West Annex" and floor == 3) do
    unit = "#{floor}0#{unit_number_base}"
    {building, unit, to_string(floor)}
  end

IO.puts("  Creating (or skipping existing) apartments...")

apartments =
  for {building, unit, floor} <- apartment_data do
    # Find-or-create by composite unique (building_name, unit_number).
    case Repo.get_by(Apartment, building_name: building, unit_number: unit) do
      %Apartment{} = existing ->
        existing

      nil ->
        {:ok, apartment} =
          Apartments.create_apartment(%{
            "building_name" => building,
            "unit_number" => unit,
            "floor" => floor
          })

        apartment
    end
  end

IO.puts("  #{length(apartments)} apartments ready.")

# ── Tenancies ────────────────────────────────────────────────
#
# House the first ~20 tenants in the first ~20 apartments. Leaves ~10
# tenants unhoused (no tenancy) and ~13 apartments vacant — both states
# are useful for exercising the filter bar's Occupancy toggle.

IO.puts("  Starting (or skipping existing) tenancies for the first 20 tenants...")

tenancies_created =
  for {tenant, apartment} <- Enum.zip(Enum.take(tenants, 20), Enum.take(apartments, 20)),
      is_nil(Apartments.get_active_tenancy_for_user(tenant)) do
    {:ok, tenancy} =
      Apartments.start_tenancy(%{
        user_id: tenant.id,
        apartment_id: apartment.id,
        # Stagger start dates across the past 6 months so tenancy
        # history looks natural.
        start_date: Date.add(Date.utc_today(), -Enum.random(30..180))
      })

    tenancy
  end

IO.puts("  #{length(tenancies_created)} new tenancies (existing tenancies skipped).")

# ── Issues ───────────────────────────────────────────────────
#
# ~30 issues reported by the housed tenants. Varied priorities +
# statuses so the admin triage view has something to look at.

issue_titles = [
  "Leaky faucet in kitchen",
  "Broken AC in bedroom",
  "Front door won't lock",
  "Water heater making noise",
  "Ceiling fan wobbles",
  "Toilet keeps running",
  "Mold near window",
  "Outlet not working",
  "Broken blinds in living room",
  "Dishwasher won't drain",
  "Shower head clogged",
  "Gap under exterior door",
  "Scratched floor tiles",
  "Missing smoke detector",
  "Cabinet hinge loose",
  "Garbage disposal stuck",
  "Paint peeling in hallway",
  "Broken window latch",
  "Refrigerator too warm",
  "Stair handrail loose"
]

priorities = [:low, :medium, :high]

# Who's got an active tenancy? Only they can report — it's the context
# rule. list_tenancies_for_apartment isn't quite what we need; just
# filter the tenants list we already have.
housed_tenants =
  for tenant <- tenants,
      not is_nil(Apartments.get_active_tenancy_for_user(tenant)),
      do: tenant

# Flatten the "1-2 issues per housed tenant" plan into a list of
# concrete job tuples up front. Keeping randomization out of the
# comprehension's generator expression makes each iteration's
# inputs visible, which pays off when a failure needs debugging.
issue_jobs =
  housed_tenants
  |> Enum.with_index()
  |> Enum.flat_map(fn {tenant, idx} ->
    Enum.map(1..Enum.random(1..2), fn _ ->
      {tenant, idx, Enum.random(issue_titles), Enum.random(priorities)}
    end)
  end)

IO.puts(
  "  Creating issues (~1-2 per housed tenant, #{length(housed_tenants)} housed, #{length(issue_jobs)} planned)..."
)

# Report each planned issue, then transition a slice of them through
# the assign / start / resolve pipeline so the admin triage view has
# a realistic mix of statuses.
#
# Errors are NOT swallowed. A seeded tenant failing to file an issue
# means the environment is inconsistent (missing profile, broken
# tenancy, etc.) and silently skipping leaves the seed looking like
# it ran while producing an empty issue table — hard to debug later.
issues_created =
  for {tenant, i, title, priority} <- issue_jobs do
    attrs = %{
      "title" => title,
      "description" => "Auto-generated demo description for '#{title}'. Reported by demo tenant.",
      "priority" => to_string(priority)
    }

    issue =
      case Issues.report_issue(tenant, attrs) do
        {:ok, issue} ->
          issue

        {:error, reason} ->
          raise """
          Demo seed: Issues.report_issue/2 failed for @#{tenant.username}.
          Reason: #{inspect(reason, pretty: true)}
          Attrs:  #{inspect(attrs, pretty: true)}
          """

        {:error, reason, extra} ->
          raise """
          Demo seed: Issues.report_issue/2 failed for @#{tenant.username}.
          Reason: #{inspect(reason, pretty: true)}
          Extra:  #{inspect(extra, pretty: true)}
          Attrs:  #{inspect(attrs, pretty: true)}
          """
      end

    # Roughly: ~10% resolved, ~20% in_progress, ~30% assigned,
    # ~40% stay :reported. Hash of title + index keeps the spread
    # stable across runs with the same seed inputs.
    case rem(i + :erlang.phash2(title), 10) do
      0 ->
        {:ok, issue} = Issues.assign_technician(issue, technician.id)
        {:ok, issue} = Issues.start_progress(issue)
        {:ok, _} = Issues.resolve_issue(issue)

      r when r in [1, 2] ->
        {:ok, issue} = Issues.assign_technician(issue, technician.id)
        {:ok, _} = Issues.start_progress(issue)

      r when r in [3, 4, 5] ->
        {:ok, _} = Issues.assign_technician(issue, technician.id)

      _ ->
        :ok
    end

    issue
  end

IO.puts("  #{length(issues_created)} issues created.")

# ── Summary ──────────────────────────────────────────────────

IO.puts("""

✅ Demo seed complete.

   Tenants:       #{length(tenants)}
   Apartments:    #{length(apartments)}
   New tenancies: #{length(tenancies_created)}
   New issues:    #{length(issues_created)}

All seeded accounts — admin, technician, and tenants —
share the same password: #{demo_password}

Log in as admin@proplex.local, tenant1@proplex.local, etc. and
visit /admin/users, /admin/apartments, /admin/issues — each should
show 20 rows with a "Load more" button.
""")
