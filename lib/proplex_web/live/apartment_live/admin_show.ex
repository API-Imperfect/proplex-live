defmodule ProplexWeb.ApartmentLive.AdminShow do
  use ProplexWeb, :live_view

  alias Proplex.Apartments

  alias Proplex.Apartments.Tenancy

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl">
        <.link
          navigate={~p"/admin/apartments"}
          class="mb-4 inline-flex items-center gap-1 text-sm text-base-content/70 hover:text-base-content hover:underline"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to Apartments
        </.link>
        <div class="rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-6 sm:px-8">
          <%!-- Header: title + badges --%>

          <div class="flex items-start justify-between gap-3 border-b border-base-300 pb-4">
            <div>
              <h1 class="text-2xl font-semibold tracking-tight">
                {@apartment.building_name} '  Unit {@apartment.unit_number}
              </h1>
              <p class="mt-1 text-sm text-base-content/70">
                {@apartment.floor}
              </p>
            </div>

            <div class="flex items-center gap-2">
              <%= if @apartment.archived_at do %>
                <span class="badge badge-warning">Archived</span>
              <% else %>
                <span class="badge badge-ghost">Active</span>
              <% end %>

              <.link
                navigate={~p"/admin/apartments/#{@apartment.id}/edit"}
                class="btn btn-ghost btn-sm"
              >
                <.icon name="hero-pencil-square" class="size-4" /> Edit
              </.link>
            </div>
          </div>

          <section :if={@active_tenancy} class="mt-6 rounded-box bg-base-100 px-6 py-4">
            <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Current tenancy
            </h2>

            <dl class="mt-3 space-y-2 text-sm">
              <div class="flex justify-between">
                <dt class="text-base-content/60">Tenant</dt>
                <dd class="font-medium">
                  @{@active_tenancy.user.username}
                </dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-base-content/60">Moved in</dt>
                <dd class="font-medium">
                  {Calendar.strftime(@active_tenancy.start_date, "%B %-d, %Y")}
                </dd>
              </div>
            </dl>

            <.form
              for={@end_form}
              id="end-tenancy-form"
              phx-submit="end_tenancy"
              class="mt-4 flex flex-wrap items-end gap-3"
            >
              <div class="min-w-[12rem] flex-1">
                <.input
                  field={@end_form[:end_date]}
                  type="date"
                  label="End date"
                />
              </div>

              <div class="fieldset mb-2">
                <span
                  class="label mb-1 block select-none opacity-0"
                  aria-hidden="true"
                >
                  spacer
                </span>
                <.button
                  phx-disable-with="Ending..."
                  data-confirm="End this tenancy? The unit will become vacant."
                  class="btn btn-outline btn-error"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> End tenancy
                </.button>
              </div>
            </.form>
          </section>

          <section
            :if={is_nil(@active_tenancy) and is_nil(@apartment.archived_at)}
            class="mt-6 rounded-box bg-base-100 px-6 py-4"
          >
            <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Start a tenancy
            </h2>

            <%= case @eligible_tenants do %>
              <% [] -> %>
                <p class="mt-3 text-sm text-base-content/70">
                  No eligible tenants right now - every tenant-role user is already housed. Register a new tenant via the signup flow, then come back here.
                </p>
              <% _tenants -> %>
                <.form
                  for={@start_form}
                  id="start-tenancy-form"
                  phx-submit="start_tenancy"
                  class="mt-3 flex flex-wrap items-end gap-3"
                >
                  <div class="min-w-[14rem] flex-1">
                    <.input
                      field={@start_form[:user_id]}
                      type="select"
                      label="Tenant"
                      options={@tenant_options}
                      prompt="- Select a tenant -"
                    />
                  </div>

                  <div class="min-w-[10rem] flex-1">
                    <.input
                      field={@start_form[:start_date]}
                      type="date"
                      label="Start date"
                    />
                  </div>
                  <div class="fieldset mb-2">
                    <span
                      class="label mb-1 block select-none opacity-0"
                      aria-hidden="true"
                    >
                      spacer
                    </span>
                    <.button phx-disable-with="Starting..." class="btn btn-primary">
                      <.icon name="hero-user-plus" class="size-4" /> Start tenancy
                    </.button>
                  </div>
                </.form>
            <% end %>
          </section>

          <section
            :if={is_nil(@active_tenancy) and not is_nil(@apartment.archived_at)}
            class="mt-6 rounded-box border border-warning/30 bg-warning/10 px-6 py-4 text-sm"
          >
            <p class="font-medium">Unit is archived.</p>
            <p class="mt-1 text-base-content/70">
              Unarchive it from the
              <.link
                navigate={~p"/admin/apartments/#{@apartment.id}/edit"}
                class="link"
              >
                edit page
              </.link>
              before starting a new tenancy.
            </p>
          </section>

          <section
            :if={@tenancy_history != []}
            class="mt-8"
          >
            <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              History
            </h2>
            <div class="mt-3 overflow-x-auto rounded-box border border-base-300 bg-base-100">
              <table class="table table-sm min-w-full">
                <thead>
                  <tr>
                    <th>Tenant</th>
                    <th>Moved in</th>
                    <th>Moved out</th>
                  </tr>
                </thead>

                <tbody>
                  <tr :for={t <- @tenancy_history} class="hover">
                    <td class="whitespace-nowrap">@{t.user.username}</td>
                    <td class="whitespace-nowrap">
                      {Calendar.strftime(t.start_date, "%b %-d, %Y")}
                    </td>
                    <td class="whitespace-nowrap">
                      {Calendar.strftime(t.end_date, "%b %-d, %Y")}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    apartment = Apartments.get_apartment!(id)

    {:ok, socket |> assign(:apartment, apartment) |> load_tenancy_state()}
  end

  @impl true
  def handle_event("start_tenancy", %{"tenancy" => attrs}, socket) do
    attrs =
      attrs
      |> Map.put("apartment_id", socket.assigns.apartment.id)

    case Apartments.start_tenancy(attrs) do
      {:ok, _tenancy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tenancy started.")
         |> load_tenancy_state()}

      {:error, :apartment_archived} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This apartment is archived. Unarchive it first."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :start_form, to_form(changeset, as: "tenancy"))}
    end
  end

  @impl true
  def handle_event("end_tenancy", %{"tenancy" => %{"end_date" => date_str}}, socket) do
    tenancy = socket.assigns.active_tenancy

    with %Tenancy{} <- tenancy,
         {:ok, %Date{} = end_date} <- Date.from_iso8601(date_str),
         {:ok, _updated} <- Apartments.end_tenancy(tenancy, end_date) do
      {:noreply,
       socket
       |> put_flash(:info, "Tenancy ended.")
       |> load_tenancy_state()}
    else
      nil ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "No active tenancy to end."
         )}

      {:error, :invalid_format} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Invalid end date."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :end_form, to_form(changeset, as: "tenancy"))}
    end
  end

  defp load_tenancy_state(socket) do
    apartment = socket.assigns.apartment

    tenancies = Apartments.list_tenancies_for_apartment(apartment)

    active = Enum.find(tenancies, &is_nil(&1.end_date))
    history = Enum.reject(tenancies, &is_nil(&1.end_date))

    eligible_tenants =
      if is_nil(active) and is_nil(apartment.archived_at) do
        Apartments.list_eligible_tenants()
      else
        []
      end

    socket
    |> assign(:active_tenancy, active)
    |> assign(:tenancy_history, history)
    |> assign(:eligible_tenants, eligible_tenants)
    |> assign(
      :tenant_options,
      Enum.map(eligible_tenants, &{"@#{&1.username} - #{&1.email}", &1.id})
    )
    |> assign(:start_form, build_start_form())
    |> assign(:end_form, build_end_form(active))
  end

  defp build_start_form do
    %Tenancy{}
    |> Tenancy.create_changeset(%{start_date: Date.utc_today()})
    |> to_form(as: "tenancy")
  end

  defp build_end_form(%Tenancy{} = tenancy) do
    tenancy
    |> Tenancy.end_changeset(%{end_date: Date.utc_today()})
    |> to_form(as: "tenancy")
  end

  defp build_end_form(nil), do: nil
end
