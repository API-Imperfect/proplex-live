defmodule ProplexWeb.IssueLive.Show do
  use ProplexWeb, :live_view

  alias Proplex.Issues
  alias Proplex.Authorization

  import ProplexWeb.IssueLive.Badges

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl">
        <.link
          navigate={~p"/issues"}
          class="mb-4 inline-flex items-center gap-1 text-sm text-base-content/70 hover:text-base-content hover:underline"
        >
          <.icon name="hero-arrow-left" class="size-4" /> Back to My Issues
        </.link>
        <div class="rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-6 sm:px-8">
          <%!-- Header: title + badges --%>
          <div class="border-b border-base-300 pb-4">
            <div class="flex items-start justify-between gap-3">
              <h1 class="text-2xl font-semibold tracking-tight">{@issue.title}</h1>
              <.status_badge status={@issue.status} />
            </div>
            <div class="mt-2 flex items-center gap-2 text-sm text-base-content/70">
              <.priority_badge priority={@issue.priority} /> priority
            </div>
          </div>
          <div class="mt-6">
            <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Description
            </h2>

            <p class="mt-2 whitespace-pre-wrap text-base-content/90">
              {@issue.description}
            </p>
          </div>
          <dl class="mt-6 space-y-3 rounded-box bg-base-100 px-6 py-4 text-sm">
            <div class="flex justify-between">
              <dt class="text-base-content/60">Apartment</dt>
              <dd class="font-medium">
                {@issue.apartment.building_name} . Unit {@issue.apartment.unit_number}
              </dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-base-content/60">Reported on</dt>
              <dd class="font-medium">
                {Calendar.strftime(@issue.inserted_at, "%B %-d, %Y")}
              </dd>
            </div>

            <div :if={@issue.assigned_technician} class="flex justify-between">
              <dt class="text-base-content/60">Assigned to</dt>
              <dd class="font-medium">@{@issue.assigned_technician.username}</dd>
            </div>

            <div :if={is_nil(@issue.assigned_technician)} class="flex justify-between">
              <dt class="text-base-content/60">Assigned to</dt>
              <dd class="text-base-content/70 italic">Awaiting assignment</dd>
            </div>

            <div :if={@issue.resolved_on} class="flex justify-between">
              <dt class="text-base-content/60">Resolved on</dt>
              <dd class="font-medium">{Calendar.strftime(@issue.resolved_on, "%B %-d, %Y")}</dd>
            </div>
          </dl>

          <div :if={@can_delete?} class="mt-6 border-t border-base-300 pt-4">
            <.button
              phx-click="delete"
              data-confirm="Delete this report? This cannot be undone from the app."
              class="btn btn-outline btn-error btn-sm"
            >
              <.icon name="hero-trash" class="size-4" /> Delete report
            </.button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_scope.user

    case Issues.get_issue(id) do
      nil ->
        {:ok, socket |> put_flash(:error, "Issue not found.") |> push_navigate(to: ~p"/issues")}

      issue ->
        cond do
          issue.reporter_id == user.id ->
            {:ok,
             socket
             |> assign(:issue, issue)
             |> assign(:can_delete?, true)}

          Authorization.has_role?(user, "admin") ->
            {:ok,
             socket
             |> assign(:issue, issue)
             |> assign(:can_delete?, false)}

          true ->
            {:ok,
             socket
             |> put_flash(:error, "Issue not found.")
             |> push_navigate(to: ~p"/issues")}
        end
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    user = socket.assigns.current_scope.user
    issue = socket.assigns.issue

    if issue.reporter_id == user.id do
      {:ok, _} = Issues.delete_issue(issue)

      {:noreply, socket |> put_flash(:info, "Report deleted.") |> push_navigate(to: ~p"/issues")}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You can only delete your own reports.")
       |> push_navigate(to: ~p"/issues")}
    end
  end
end
