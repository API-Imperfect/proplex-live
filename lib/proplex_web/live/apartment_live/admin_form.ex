defmodule ProplexWeb.ApartmentLive.AdminForm do
  use ProplexWeb, :live_view

  alias Proplex.Apartments
  alias Proplex.Apartments.Apartment

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-xl">
        <.link
          navigate={~p"/admin/apartments"}
          class="mb-4 inline-flex items-center gap-1 text-sm text-base-content/70 hover:text-base-content hover:underline"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to Apartments
        </.link>
        <div class="rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-6 sm:px-8">
          <%!-- Header: title + badges --%>
          <div class="mb-6 flex items-start justify-between gap-3 border-b border-base-300 pb-4">
            <div>
              <h1 class="text-2xl font-semibold tracking-tight">
                {if @live_action == :new, do: "New apartment", else: "Edit apartment"}
              </h1>
              <p :if={@live_action == :edit} class="mt-1 text-sm text-base-content/70">
                {@apartment.building_name} . Unit {@apartment.unit_number}
              </p>
            </div>

            <div :if={@live_action == :edit}>
              <%= if @apartment.archived_at do %>
                <span class="badge badge-warning">Archived</span>
              <% else %>
                <span class="badge badge-ghost">Active</span>
              <% end %>
            </div>
          </div>

          <.form
            for={@form}
            id="apartment-form"
            phx-change="validate"
            phx-submit="save"
            phx-debounce="400"
          >
            <.input
              field={@form[:building_name]}
              type="text"
              label="Building name"
              placeholder="e.g. North Tower"
              required
            />
            <.input
              field={@form[:unit_number]}
              type="text"
              label="Unit number"
              placeholder="e.g. 101"
              required
            />

            <.input
              field={@form[:floor]}
              type="text"
              label="Floor"
              placeholder="e.g. 1, Ground, Basement"
              required
            />

            <div class="mt-6 grid grid-cols-1 gap-2 sm:grid-cols-3">
              <.link navigate={~p"/admin/apartments"} class="btn btn-outline w-full">
                Cancel
              </.link>
              <.button phx-disable-with="-Saving..." class="btn btn-primary w-full sm:col-span-2">
                {if @live_action == :new, do: "Create apartment", else: "Save changes"}
              </.button>
            </div>
          </.form>

          <div :if={@live_action == :edit} class="mt-8 border-t border-base-300 pt-6">
            <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Status
            </h2>
            <%= if @apartment.archived_at do %>
              <p class="mt-2 text-sm text-base-content/70">
                This unit is currently archived. Unarchive to bring it back online.
              </p>
              <.button
                phx-click="unarchive"
                phx-disable-with="Unarchiving..."
                class="btn btn-outline btn-primary btn-sm mt-3"
              >
                <.icon name="hero-arrow-uturn-left" class="size-4" /> Unarchive
              </.button>
            <% else %>
              <p class="mt-2 text-sm text-base-content/70">
                Archiving hides the unit from active inventory and blocks new tenancies. Existing tenancies must be ended first.
              </p>
              <.button
                phx-click="archive"
                phx-disable-with="Archiving..."
                data-confirm="Archive this apartment? It will stop accepting new tenancies"
                class="btn btn-outline btn-error btn-sm mt-3"
              >
                <.icon name="hero-archive-box" class="size-4" /> Archive
              </.button>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    apartment = load_apartment(socket.assigns.live_action, params)

    changeset = Apartments.change_apartment(apartment)

    {:ok, socket |> assign(:apartment, apartment) |> assign_form(changeset)}
  end

  defp load_apartment(:new, _params), do: %Apartment{}
  defp load_apartment(:edit, %{"id" => id}), do: Apartments.get_apartment!(id)

  @impl true
  def handle_event("validate", %{"apartment" => attrs}, socket) do
    changeset =
      socket.assigns.apartment
      |> Apartments.change_apartment(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"apartment" => attrs}, socket) do
    save_apartment(socket, socket.assigns.live_action, attrs)
  end

  def handle_event("archive", _params, socket) do
    case Apartments.archive_apartment(socket.assigns.apartment) do
      {:ok, apartment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Apartment archived.")
         |> assign(:apartment, apartment)
         |> assign_form(Apartments.change_apartment(apartment))}

      {:error, :active_tenancy_exists} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Can't archive this unit while a tenancy is active. End the tenancy first."
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't archive the apartment")}
    end
  end

  def handle_event("unarchive", _params, socket) do
    case Apartments.unarchive_apartment(socket.assigns.apartment) do
      {:ok, apartment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Apartment unarchived.")
         |> assign(:apartment, apartment)
         |> assign_form(Apartments.change_apartment(apartment))}

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Couldn't unarchive the apartment."
         )}
    end
  end

  defp save_apartment(socket, :new, attrs) do
    case Apartments.create_apartment(attrs) do
      {:ok, _aparment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Apartment created.")
         |> push_navigate(to: ~p"/admin/apartments")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_apartment(socket, :edit, attrs) do
    case Apartments.update_apartment(socket.assigns.apartment, attrs) do
      {:ok, apartment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Apartment updated.")
         |> assign(:apartment, apartment)
         |> assign_form(Apartments.change_apartment(apartment))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "apartment"))
  end
end
