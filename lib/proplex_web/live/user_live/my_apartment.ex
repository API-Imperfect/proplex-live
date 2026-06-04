defmodule ProplexWeb.UserLive.MyApartment do
  use ProplexWeb, :live_view

  alias Proplex.Apartments

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-home" class="size-9 text-primary" />
          </div>

          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">My Apartment</h1>
          </div>

          <%= case @tenancy do %>
            <% nil -> %>
              <div class="rounded-box bg-base-100 px-6 py-8 text-center">
                <.icon name="hero-building-office-2" class="size-12 text-base-content/40" />
                <p class="mt-4 font-medium">You haven't been assigned to an apartment yet.</p>

                <p class="mt-2 text-sm text-base-content/70 ">
                  Your landlord will assign your unit when your lease is set up. If you believe this is a mistake, please contact them.
                </p>
              </div>
            <% tenancy -> %>
              <div class="space-y-4">
                <div class="rounded-box bg-base-100 px-6 py-6 text-center">
                  <p class="text-sm uppercase tracking-wide text-base-content/60">
                    {tenancy.apartment.building_name}
                  </p>
                  <p class="mt-2 text-3xl font-semibold">Unit {tenancy.apartment.unit_number}</p>
                </div>
                <dl class="space-y-3 rounded-box bg-base-100 px-6 py-4 text-sm">
                  <div class="flex justify-between">
                    <dt class="text-base-content/60">Floor</dt>
                    <dd class="font-medium">{tenancy.apartment.floor}</dd>
                  </div>

                  <div class="flex justify-between">
                    <dt class="text-base-content/60">Tenant since</dt>
                    <dd class="font-medium">{Calendar.strftime(tenancy.start_date, "%B %-d, %Y")}</dd>
                  </div>
                </dl>

                <.link navigate={~p"/issues/new"} class="btn btn-primary w-full">
                  <.icon name="hero-wrench-screwdriver" class="size-4" /> Report an issue
                </.link>

                <p class="text-center text-xs text-base-content/60">
                  Need to report an issue or change your unit? Contact your landlord.
                </p>
              </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _sessions, socket) do
    tenancy = Apartments.get_active_tenancy_for_user(socket.assigns.current_scope.user)

    {:ok, assign(socket, :tenancy, tenancy)}
  end
end
