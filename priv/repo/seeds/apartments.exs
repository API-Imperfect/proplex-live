# Apartment seeds — the landlord's inventory of physical units.
# Loaded by priv/repo/seeds.exs (runs after rbac.exs).
#
# These represent the units that exist in the complex, whether or
# not anyone currently lives in them. Tenancies (actual leases) are
# NOT seeded — they couple to specific user ids that don't exist on
# a fresh `mix ecto.setup`. Assign tenancies manually via IEx:
#
#     user = Proplex.Repo.get_by!(Proplex.Accounts.User, email: "...")
#     apt  = Proplex.Repo.get_by!(Proplex.Apartments.Apartment,
#              building_name: "North Tower", unit_number: "101")
#     Proplex.Apartments.start_tenancy(%{
#       user_id: user.id,
#       apartment_id: apt.id,
#       start_date: Date.utc_today()
#     })
#
# Once the admin panel (deferred) ships, this becomes point-and-click.

alias Proplex.Repo
alias Proplex.Apartments.Apartment

apartments =
  [
    # North Tower — floors 1 and 2
    {"North Tower", "101", "1"},
    {"North Tower", "102", "1"},
    {"North Tower", "201", "2"},
    {"North Tower", "202", "2"},
    # South Block — ground floor units
    {"South Block", "G1", "Ground"},
    {"South Block", "G2", "Ground"}
  ]
  |> Enum.map(fn {building, unit, floor} ->
    now = DateTime.utc_now(:second)

    %{
      building_name: building,
      unit_number: unit,
      floor: floor,
      inserted_at: now,
      updated_at: now
    }
  end)

# on_conflict: :nothing with a conflict_target on the composite unique
# index makes this idempotent — running seeds twice is a no-op.
Repo.insert_all(Apartment, apartments,
  on_conflict: :nothing,
  conflict_target: [:building_name, :unit_number]
)
