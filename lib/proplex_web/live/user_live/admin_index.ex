defmodule ProplexWeb.UserLive.AdminIndex do
  use ProplexWeb, :live_view

  alias Proplex.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="w-full">
        <div class="mb-6">
          <h1 class="text-2xl font-semibold tracking-tight">Users</h1>
          <p class="mt-1 text-sm text-base-content/70">
            Everyone with an account, newest first. Click a username to change their role
          </p>
        </div>

        <%= case @rows do %>
          <%!-- Empty state — no registered users yet. --%>
          <% [] -> %>
            <div class="rounded-box border border-base-300 bg-base-200 px-6 py-12 text-center">
              <.icon name="hero-users" class="size-12 text-base-content/40" />
              <p class="mt-4 font-medium">No users yet.</p>
              <p class="mt-2 text-sm text-base-content/70">
                Registrations will appear here.
              </p>
            </div>
          <% rows -> %>
            <div class="overflow-x-auto rounded-box border border-base-300 bg-base-200">
              <table class="table table-sm min-w-full">
                <thead>
                  <tr>
                    <th>Username</th>
                    <th>Email</th>
                    <th>Role</th>
                    <th>Registered</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={row <- rows} class="hover">
                    <%!-- Username is the only link in the row — same
                        "one primary action per row" pattern as other
                        admin tables. --%>
                    <td class="whitespace-nowrap font-medium">
                      <.link
                        navigate={~p"/admin/users/#{row.user.id}/edit"}
                        class="hover:underline"
                      >
                        @{row.user.username}
                      </.link>
                      <%!-- "you" badge on the admin's own row — signals
                          early that self-demotion isn't allowed on the
                          edit page. --%>
                      <span
                        :if={row.user.id == @current_scope.user.id}
                        class="badge badge-ghost badge-sm ml-1"
                      >
                        you
                      </span>
                    </td>
                    <td class="whitespace-nowrap">{row.user.email}</td>
                    <td class="whitespace-nowrap">
                      <%!-- role_name can be nil (LEFT JOIN, no global role).
                          Show an explicit placeholder so the gap is visible. --%>
                      <%= case row.role_name do %>
                        <% nil -> %>
                          <span class="italic text-base-content/50">
                            (no role)
                          </span>
                        <% name -> %>
                          <span class={["badge", role_badge_class(name)]}>
                            {name}
                          </span>
                      <% end %>
                    </td>
                    <td class="whitespace-nowrap text-base-content/70">
                      {Calendar.strftime(row.user.inserted_at, "%b %-d, %Y")}
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
    rows = Accounts.list_users_for_admin()
    {:ok, assign(socket, :rows, rows)}
  end

  defp role_badge_class("admin"), do: "badge-primary"
  defp role_badge_class("technician"), do: "badge-warning"
  defp role_badge_class("tenant"), do: "badge-ghost"
  defp role_badge_class(_), do: "badge-ghost"
end
