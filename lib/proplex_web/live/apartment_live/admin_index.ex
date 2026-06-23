defmodule ProplexWeb.ApartmentLive.AdminIndex do
  use ProplexWeb, :live_view

  alias Proplex.Apartments

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-full">
        <div class="mb-6">
          <h1 class="text-2xl font-semibold tracking-tight">Apartments</h1>
          <p class="mt-1 text-sm text-base-content/70">
            Every unit across every building, with current occupant.
          </p>
        </div>

        <form phx-change="filter" class="mb-4 flex flex-wrap items-end gap-4">
          <div>
            <div class="mb-1 text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Occupancy
            </div>

            <div class="join">
              <input
                type="radio"
                name="occupancy"
                value="all"
                aria-label="All"
                class="btn btn-sm join-item"
                checked={@filters.occupancy == "all"}
              />
              <input
                type="radio"
                name="occupancy"
                value="vacant"
                aria-label="Vacant"
                class="btn btn-sm join-item"
                checked={@filters.occupancy == "vacant"}
              />
              <input
                type="radio"
                name="occupancy"
                value="occupied"
                aria-label="Occupied"
                class="btn btn-sm join-item"
                checked={@filters.occupancy == "occupied"}
              />
            </div>
          </div>

          <div>
            <label
              for="filter-building"
              class="mb-1 block text-xs font-semibold uppercase tracking-wide text-base-content/60"
            >
              Building
            </label>
            <select id="filter-building" name="building_name" class="select select-sm">
              <option value="" selected={@filters.building_name == ""}>All buildings</option>

              <option
                :for={name <- @building_names}
                value={name}
                selected={@filters.building_name == name}
              >
                {name}
              </option>
            </select>
          </div>

          <div>
            <label class="label cursor-pointer gap-2">
              <input type="hidden" name="include_archived" value="false" />
              <input
                type="checkbox"
                name="include_archived"
                value="true"
                class="checkbox checkbox-sm"
                checked={@filters.include_archived}
              />
              <span class="label-text">Include archived</span>
            </label>
          </div>

          <div :if={filters_active?(@filters)} class="ml-auto">
            <button type="button" phx-click="reset_filters" class="btn btn-ghost btn-sm">
              Reset filters
            </button>
          </div>
        </form>

        <p class="mb-2 text-xs text-base-content/60">
          Showing {length(@apartments)} {pluralize(length(@apartments), "apartment", "apartments")}
        </p>

        <%= case @apartments do %>
          <% [] -> %>
            <div class="rounded-box border border-base-300 bg-base-200 px-6 py-12 text-center">
              <.icon name="hero-building-office-2" class="size-12 text-base-content/40" />
              <p class="mt-4 font-medium">No apartments match these filters.</p>
              <p class="mt-2 text-sm text-base-content/70">
                Try widening the filters or resetting.
              </p>
            </div>
          <% rows -> %>
            <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
              <table class="table table-sm min-w-full">
                <thead>
                  <tr>
                    <th>Building</th>
                    <th>Unit</th>
                    <th>Floor</th>
                    <th>Current tenant</th>
                    <th>Status</th>
                  </tr>
                </thead>

                <tbody>
                  <tr :for={row <- rows} class="hover">
                    <td class="whitespace-nowrap font-medium">
                      {row.apartment.building_name}
                    </td>
                    <td class="whitespace-nowrap">
                      {row.apartment.unit_number}
                    </td>
                    <td class="whitespace-nowrap">
                      {row.apartment.floor}
                    </td>
                    <td class="whitespace-nowrap">
                      <%= if row.current_tenant do %>
                        @{row.current_tenant.username}
                      <% else %>
                        <span class="italic text-base-content/50">Vacant</span>
                      <% end %>
                    </td>

                    <td class="whitespace-nowrap">
                      <%= if row.apartment.archived_at do %>
                        <span class="badge badge-warning">Archived</span>
                      <% else %>
                        <span class="badge badge-ghost">Active</span>
                      <% end %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    filters = default_filters()

    building_names = Apartments.list_building_names()

    apartments = Apartments.list_apartments_with_current_tenant(filters_to_opts(filters))

    {:ok,
     socket
     |> assign(:filters, filters)
     |> assign(:building_names, building_names)
     |> assign(:apartments, apartments)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      occupancy: params["occupancy"] || "all",
      building_name: params["building_name"] || "",
      include_archived: params["include_archived"] == "true"
    }

    apartments =
      Apartments.list_apartments_with_current_tenant(filters_to_opts(filters))

    {:noreply, socket |> assign(:filters, filters) |> assign(:apartments, apartments)}
  end

  def handle_event("reset_filters", _params, socket) do
    filters = default_filters()

    apartments =
      Apartments.list_apartments_with_current_tenant(filters_to_opts(filters))

    {:noreply, socket |> assign(:filters, filters) |> assign(:apartments, apartments)}
  end

  defp default_filters do
    %{occupancy: "all", building_name: "", include_archived: true}
  end

  defp filters_active?(%{occupancy: occ, building_name: bn, include_archived: ia}) do
    occ != "all" or bn != "" or ia != true
  end

  defp filters_to_opts(%{occupancy: occ, building_name: bn, include_archived: ia}) do
    [
      include_archived: ia,
      building_name: if(bn == "", do: nil, else: bn),
      occupancy: occupancy_atom(occ)
    ]
  end

  defp occupancy_atom("vacant"), do: :vacant
  defp occupancy_atom("occupied"), do: :occupied
  defp occupancy_atom(_), do: :all

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_, _singular, plural), do: plural
end
