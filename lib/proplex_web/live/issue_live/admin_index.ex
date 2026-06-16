defmodule ProplexWeb.IssueLive.AdminIndex do
  use ProplexWeb, :live_view

  alias Proplex.Issues
  import ProplexWeb.IssueLive.Badges

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-full">
        <div class="mb-6">
          <h1 class="text-2xl font-semibold tracking-tight">All Issues</h1>
          <p class="mt-1 text-sm text-base-content/70">
            Every reported issue across every apartment, newest first.
          </p>
        </div>

        <%= case @issues do %>
          <% [] -> %>
            <div class="rounded-box border border-base-300 bg-base-200 px-6 py-12 text-center">
              <.icon name="hero-clipboard-document-list" class="size-12 text-base-content/40" />
              <p class="mt-4 font-medium">No issues reported yet.</p>
              <p class="mt-2 text-sm text-base-content/70">
                When tenants start reporting issues, they will appear here for triage.
              </p>
            </div>
          <% issues -> %>
            <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
              <table class="table table-sm min-w-full">
                <thead>
                  <tr>
                    <th>Title</th>
                    <th>Reporter</th>
                    <th>Apartment</th>
                    <th>Status</th>
                    <th>Priority</th>
                    <th>Assignee</th>
                    <th>Reported</th>
                  </tr>
                </thead>

                <tbody>
                  <tr :for={issue <- issues} class="hover">
                    <td class="w-2/5">
                      <.link
                        navigate={~p"/issues/#{issue.id}"}
                        class="font-medium hover:underline"
                      >
                        {issue.title}
                      </.link>
                    </td>
                    <td class="whitespace-nowrap">
                      @{issue.reporter.username}
                    </td>
                    <td class="whitespace-nowrap">
                      {issue.apartment.building_name} . Unit {issue.apartment.unit_number}
                    </td>

                    <td class="whitespace-nowrap">
                      <.status_badge status={issue.status} />
                    </td>

                    <td class="whitespace-nowrap">
                      <.priority_badge priority={issue.priority} />
                    </td>

                    <td class="whitespace-nowrap">
                      <%= if issue.assigned_technician do %>
                        @{issue.assigned_technician.username}
                      <% else %>
                        <span class="italic text-base-content/50">
                          Unassigned
                        </span>
                      <% end %>
                    </td>

                    <td class="whitespace-nowrap text-base-content/70">
                      {Calendar.strftime(issue.inserted_at, "%b %-d, %Y")}
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
    issues = Issues.list_all_issues()

    {:ok, assign(socket, :issues, issues)}
  end
end
