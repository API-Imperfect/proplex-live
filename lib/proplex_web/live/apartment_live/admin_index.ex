defmodule ProplexWeb.ApartmentLive.AdminIndex do
  use ProplexWeb, :live_view

  alias Proplex.Apartments

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-full">
        <div class="mb-6 flex items-start justify-between gap-3">
          <div>
            <h1 class="text-2xl font-semibold tracking-tight">Apartments</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Every unit across every building, with current occupant.
            </p>
          </div>
          <.link navigate={~p"/admin/apartments/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New apartment
          </.link>
        </div>

        <form phx-change="filter" class="mb-4 flex flex-wrap items-end gap-4">
          <div>
            <label
              for="filter-sort"
              class="mb-1 block text-xs font-semibold uppercase tracking-wide text-base-content/60"
            >
              Sort
            </label>
            <select id="filter-sort" name="sort" class="select select-sm">
              <option
                :for={{label, value} <- @sort_options}
                value={value}
                selected={@filters.sort == value}
              >
                {label}
              </option>
            </select>
          </div>
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
                      <.link
                        navigate={~p"/admin/apartments/#{row.apartment.id}"}
                        class="hover:underline"
                      >
                        {row.apartment.building_name}
                      </.link>
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
            <div :if={@next_cursor} class="mt-4 flex justify-center">
              <.button
                id="load-more-apartments"
                phx-click="load_more"
                phx-disable-with="Loading..."
                class="btn btn-outline btn-sm"
              >
                <.icon name="hero-arrow-down" class="size-4" /> Load more
              </.button>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:building_names, Apartments.list_building_names())
     |> assign(:sort_options, Apartments.apartment_sort_options())
     |> load_first_page(default_filters())}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      occupancy: params["occupancy"] || "all",
      building_name: params["building_name"] || "",
      include_archived: params["include_archived"] == "true",
      sort: params["sort"] || Apartments.default_apartment_sort()
    }

    {:noreply, load_first_page(socket, filters)}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply, load_first_page(socket, default_filters())}
  end

  def handle_event("load_more", _params, %{assigns: %{next_cursor: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("load_more", _params, socket) do
    opts = filters_to_opts(socket.assigns.filters) ++ [cursor: socket.assigns.next_cursor]
    page = Apartments.list_apartments_with_current_tenant(opts)

    {:noreply,
     socket
     |> assign(:apartments, socket.assigns.apartments ++ page.rows)
     |> assign(:next_cursor, page.next_cursor)}
  end

  defp load_first_page(socket, filters) do
    page = Apartments.list_apartments_with_current_tenant(filters_to_opts(filters))

    socket
    |> assign(:filters, filters)
    |> assign(:apartments, page.rows)
    |> assign(:next_cursor, page.next_cursor)
  end

  defp default_filters do
    %{
      occupancy: "all",
      building_name: "",
      include_archived: true,
      sort: Apartments.default_apartment_sort()
    }
  end

  defp filters_active?(%{occupancy: occ, building_name: bn, include_archived: ia, sort: sort}) do
    occ != "all" or bn != "" or ia != true or sort != Apartments.default_apartment_sort()
  end

  defp filters_to_opts(%{occupancy: occ, building_name: bn, include_archived: ia, sort: sort}) do
    [
      include_archived: ia,
      building_name: if(bn == "", do: nil, else: bn),
      occupancy: occupancy_atom(occ),
      sort: sort
    ]
  end

  defp occupancy_atom("vacant"), do: :vacant
  defp occupancy_atom("occupied"), do: :occupied
  defp occupancy_atom(_), do: :all

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_, _singular, plural), do: plural
end
