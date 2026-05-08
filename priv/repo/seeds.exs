# Seed orchestrator. Loads each feature-specific seed file in order.
#
# Run via:
#
#     mix run priv/repo/seeds.exs
#
# This is also invoked automatically by the `mix ecto.setup` alias
# (see mix.exs) — so dropping, recreating, and re-seeding the dev DB
# is a single command: `mix ecto.reset`.
#
# Each feature's seeds live in a separate file under priv/repo/seeds/.
# Add new feature seed files here in the order they should run — later
# files can assume earlier ones have completed. All sub-files use
# on_conflict: :nothing (or equivalent find-or-create patterns) so
# running the whole thing twice is a no-op.
#
# Sub-files can also be run in isolation if you only want to re-seed
# one feature:
#
#     mix run priv/repo/seeds/rbac.exs

# Path to the directory containing this script — used as the base
# for resolving the sub-seed files regardless of where the command
# was invoked from.
seeds_dir = Path.join(__DIR__, "seeds")

IO.puts("== Seeding RBAC (permissions, roles, assignments) ==")
Code.require_file(Path.join(seeds_dir, "rbac.exs"))

IO.puts("== Seeding Apartments ==")
Code.require_file(Path.join(seeds_dir, "apartments.exs"))

# Users must run AFTER rbac (which creates the admin/technician roles
# that these users get assigned to). Apartments ordering is independent,
# but keeping it "inventory before people" is a nicer mental model.
IO.puts("== Seeding Users (admin + technician) ==")
Code.require_file(Path.join(seeds_dir, "users.exs"))

IO.puts("Done.")
