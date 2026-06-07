defmodule ProplexWeb.IssueLive.Index do
  use ProplexWeb, :live_view

  alias Proplex.Issues
  import ProplexWeb.IssueLive.Badges

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl">
        <div class="mb-6 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold tracking-tight">My Issues</h1>
            <p class="mt-1 text-sm text-base-content/70">
              Everything you've reported, newest first. Click card for details
            </p>
          </div>

          <.link navigate={~p"/issues/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> Report an issue
          </.link>
        </div>

        <%= case @issues do %>
          <% [] -> %>
            <div class="rounded-box border border-base-300 bg-base-200 px-6 py-12 text-center">
              <.icon name="hero-clipboard-document-list" class="size-12 text-base-content/40" />
              <p class="mt-4 font-medium">You haven't reported any issues yet.</p>
              <p class="mt-2 text-sm text-base-content/70">
                When something needs fixing in your unit, file a report here and your landlord will take it from there.
              </p>
              <.link
                navigate={~p"/issues/new"}
                class="btn btn-primary mt-4"
              >
                Report an issue
              </.link>
            </div>
          <% issues -> %>
            <div class="space-y-3">
              <.link
                :for={issue <- issues}
                navigate={~p"/issues/#{issue.id}"}
                class="block rounded-box border border-base-300 bg-base-200 px-5 py-4 transition-colors hover:border-base-content/40"
              >
                <div class="flex items-start justify-between gap-3">
                  <h2 class="text-base font-semibold">{issue.title}</h2>
                  <.status_badge status={issue.status} />
                </div>

                <div class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-base-content/70">
                  <.priority_badge priority={issue.priority} />
                  <span>
                    <.icon name="hero-home" class="size-3" />
                    {issue.apartment.building_name} . Unit {issue.apartment.unit_number}
                  </span>

                  <span>
                    <.icon name="hero-calendar" class="size-3" />
                    Reported {Calendar.strftime(issue.inserted_at, "%b %-d, %Y")}
                  </span>

                  <span :if={issue.assigned_technician}>
                    <.icon name="hero-wrench-screwdriver" class="size-3" />
                    Assigned to @{issue.assigned_technician.username}
                  </span>
                </div>
              </.link>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    issues = Issues.list_issues_for_reporter(user)

    {:ok, assign(socket, :issues, issues)}
  end
end
