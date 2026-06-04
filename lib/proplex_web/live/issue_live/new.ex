defmodule ProplexWeb.IssueLive.New do
  use ProplexWeb, :live_view

  alias Proplex.Apartments
  alias Proplex.Issues
  alias Proplex.Issues.Issue

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-xl">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <%!-- icon seal — same design language as auth / profile pages --%>
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-wrench-screwdriver" class="size-9 text-primary" />
          </div>

          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">Report an issue</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Tell your landlord what needs fixing. They'll assign a technician and update you as it progresses.
            </p>
          </div>

          <%= case @apartment do %>
            <% nil -> %>
              <div class="rounded-box bg-base-100 px-6 py-8 text-center">
                <.icon name="hero-building-office-2" class="size-12 text-base-content/40" />
                <p class="mt-4 font-medium">You haven't been assigned to an apartment yet.</p>
                <p class="mt-2 text-sm text-base-content/70">
                  You need an active apartment before you can report issues. Please contact your landlord.
                </p>
                <.link
                  navigate={~p"/users/my-apartment"}
                  class="btn btn-outline btn-sm mt-4"
                >
                  Go to My Apartment
                </.link>
              </div>
            <% apartment -> %>
              <div class="mb-6 rounded-box border border-base-300 bg-base-100 px-4 py-3 text-sm">
                <span class="text-base-content/60">Reporting for:</span>
                <span class="font-medium">
                  {apartment.building_name} . Unit {apartment.unit_number} . Floor {apartment.floor}
                </span>
              </div>

              <.form
                for={@form}
                id="issue_report_form"
                phx-change="validate"
                phx-submit="save"
                phx-debounce="400"
              >
                <.input
                  field={@form[:title]}
                  type="text"
                  label="Title"
                  placeholder="e.g. Leaky faucet in kitchen"
                  required
                  phx-mounted={JS.focus()}
                />
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  A short summary (3-120 characters).
                </p>

                <.input
                  field={@form[:description]}
                  type="textarea"
                  label="Description"
                  placeholder="Descrive what's happening, when it started, and anything you've tried."
                  required
                />
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  Details that help the technician diagnose (10-2000 characters).
                </p>

                <.input
                  field={@form[:priority]}
                  type="select"
                  label="Priority"
                  options={priority_options()}
                />
                <p class="-mt-1 mb-3 text-xs text-base-content/60">
                  Low = cosmetic. Medium = inconvinient but functional. High = urgent / safety.
                </p>
                <div class="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-3">
                  <.link
                    navigate={~p"/users/my-apartment"}
                    class="btn btn-outline w-full"
                  >
                    Cancel
                  </.link>

                  <.button
                    phx-disable-with="Reporting..."
                    class="btn btn-primary w-full sm:col-span-2"
                  >
                    Submit report
                  </.button>
                </div>
              </.form>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    apartment = Apartments.get_current_apartment_for_user(user)

    changeset = Issues.change_issue_report()

    {:ok, socket |> assign(:apartment, apartment) |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"issue" => _attrs}, socket) do
    changeset =
      %Issue{}
      |> Issues.change_issue_report()
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"issue" => attrs}, socket) do
    user = socket.assigns.current_scope.user

    case Issues.report_issue(user, attrs) do
      {:ok, _issue} ->
        {:noreply,
         socket
         |> put_flash(:info, "Issue reported. Your landlord will be notified.")
         |> push_navigate(to: ~p"/users/my-apartment")}

      {:error, :no_active_tenancy} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have an active apartment. Please contact your landlord.")
         |> push_navigate(to: ~p"/users/my-apartment")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "issue"))
  end

  defp priority_options do
    [
      {"Low - cosmetic or non-urgent", :low},
      {"Medium - functional but inconvinient", :medium},
      {"High - urgent or safety concern", :high}
    ]
  end
end
