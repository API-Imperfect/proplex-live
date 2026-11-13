defmodule ProplexWeb.UserLive.AdminEdit do
  use ProplexWeb, :live_view

  alias Proplex.Apartments
  alias Proplex.Accounts
  alias Proplex.Authorization

  @role_options ~w(tenant technician admin)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-xl">
        <.link
          navigate={~p"/admin/users"}
          class="mb-4 inline-flex items-center gap-1 text-sm text-base-content/70 hover:text-base-content hover:underline"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to Users
        </.link>

        <div class="rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-6 sm:px-8">
          <%!-- Header: user identity + current role badge. --%>
          <div class="flex items-start justify-between gap-3 border-b border-base-300 pb-4">
            <div>
              <h1 class="text-2xl font-semibold tracking-tight">@{@user.username}</h1>
              <p class="mt-1 text-sm text-base-content/70">{@user.email}</p>
            </div>
            <span class={["badge", role_badge_class(@current_role)]}>
              {@current_role || "(no role)"}
            </span>
          </div>

          <div
            :if={@self_edit?}
            class="mt-6 rounded-box border border-warning/30 bg-warning/10 px-6 py-4 text-sm"
          >
            <p class="font-medium">You can't change your own role.</p>
            <p class="mt-1 text-base-content/70">
              To avoid locking yourself out, self-edits are disabled. Ask another admin to change your role if needed.
            </p>
          </div>

          <div :if={not @self_edit?} class="mt-6">
            <.form
              for={@form}
              id="admin-user-role-form"
              phx-submit="save"
            >
              <.input
                field={@form[:role]}
                type="select"
                label="Role"
                options={@role_options_for_select}
              />

              <div
                :if={@active_tenancy}
                class="mt-3 rounded-box border border-base-300 bg-base-100 px-4 py-3 text-sm"
              >
                <p class="font-medium">Active tenancy</p>
                <p class="mt-1 text-base-content/70">
                  This user currently rents <strong>
                  {@active_tenancy.apartment.building_name} · Unit {@active_tenancy.apartment.unit_number}
                </strong>. Changing their role does NOT end the tenancy — visit
                  <.link
                    navigate={~p"/admin/apartments/#{@active_tenancy.apartment.id}"}
                    class="link"
                  >
                    the apartment page
                  </.link>
                  to end it if needed.
                </p>
              </div>
              <div class="mt-6 grid grid-cols-1 gap-2 sm:grid-cols-3">
                <.link navigate={~p"/admin/users"} class="btn btn-outline w-full">
                  Cancel
                </.link>
                <.button
                  phx-disable-with="Saving..."
                  class="btn btn-primary w-full sm:col-span-2"
                >
                  Save role
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user!(id)

    current_role = current_global_role(user)

    self_edit? = user.id == socket.assigns.current_scope.user.id

    active_tenancy =
      case Apartments.get_active_tenancy_for_user(user) do
        nil -> nil
        tenancy -> Proplex.Repo.preload(tenancy, :apartment)
      end

    changeset = change_role_form(%{"role" => current_role})

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:current_role, current_role)
     |> assign(:self_edit?, self_edit?)
     |> assign(:active_tenancy, active_tenancy)
     |> assign(:role_options_for_select, @role_options)
     |> assign(:form, to_form(changeset, as: "role_form"))}
  end

  @impl true
  def handle_event("save", %{"role_form" => %{"role" => new_role}}, socket) do
    cond do
      socket.assigns.self_edit? ->
        {:noreply, put_flash(socket, :error, "You can't change your own role.")}

      new_role not in @role_options ->
        {:noreply, put_flash(socket, :error, "Unknown role.")}

      new_role == socket.assigns.current_role ->
        {:noreply, put_flash(socket, :info, "Role unchanged.")}

      true ->
        case Authorization.replace_user_role(socket.assigns.user, new_role) do
          {:ok, _role} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               "@#{socket.assigns.user.username} is now #{new_role}."
             )
             |> push_navigate(to: ~p"/admin/users")}

          {:error, :role_not_found} ->
            {:noreply, put_flash(socket, :error, "Role not found.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Couldn't update role. Please try again.")}
        end
    end
  end

  defp current_global_role(user) do
    user
    |> Authorization.list_user_roles()
    |> Enum.find(&is_nil(&1.property_id))
    |> case do
      nil -> nil
      %{name: name} -> name
    end
  end

  defp change_role_form(params) do
    types = %{role: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
  end

  defp role_badge_class("admin"), do: "badge-primary"
  defp role_badge_class("technician"), do: "badge-warning"
  defp role_badge_class("tenant"), do: "badge-ghost"
  defp role_badge_class(_), do: "badge-ghost"
end
