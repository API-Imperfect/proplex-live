defmodule Proplex.Issues do
  import Ecto.Query
  require Logger

  alias Proplex.Repo
  alias Proplex.Apartments
  alias Proplex.Issues.Issue

  def report_issue(%{id: reporter_id} = reporter, attrs) do
    case Apartments.get_current_apartment_for_user(reporter) do
      nil ->
        {:error, :no_active_tenancy}

      apartment ->
        attrs =
          attrs
          |> normalize_attrs()
          |> Map.put("reporter_id", reporter_id)
          |> Map.put("apartment_id", apartment.id)

        result =
          %Issue{}
          |> Issue.report_changeset(attrs)
          |> Repo.insert()

        case result do
          {:ok, issue} ->
            Logger.info("Issue reported",
              event: :issue_reported,
              issue_id: issue.id,
              reporter_id: issue.reporter_id,
              apartment_id: issue.apartment_id,
              priority: issue.priority
            )

            {:ok, issue}

          other ->
            other
        end
    end
  end

  def assign_technician(%Issue{} = issue, technician_id) do
    result =
      issue
      |> Issue.assign_changeset(%{"assigned_technician_id" => technician_id})
      |> Repo.update()

    case result do
      {:ok, updated} ->
        Logger.info("Issue assigned to technician",
          event: :issue_assigned,
          issue_id: updated.id,
          assigned_technician_id: updated.assigned_technician_id
        )

        {:ok, updated}

      other ->
        other
    end
  end

  def start_progress(%Issue{status: :reported} = issue) do
    result =
      issue
      |> Issue.start_progress_changeset()
      |> Repo.update()

    case result do
      {:ok, updated} ->
        Logger.info("Issue moved to in_progress",
          event: :issue_progress_started,
          issue_id: updated.id,
          assigned_technician_id: updated.assigned_technician_id
        )

        {:ok, updated}

      other ->
        other
    end
  end

  def resolve_issue(%Issue{status: :in_progress} = issue) do
    result =
      issue
      |> Issue.resolve_changeset()
      |> Repo.update()

    case result do
      {:ok, updated} ->
        Logger.info("Issue resolved",
          event: :issue_resolved,
          issue_id: updated.id,
          assigned_technician_id: updated.assigned_technician_id,
          resolved_on: Date.to_iso8601(updated.resolved_on)
        )

        {:ok, updated}

      other ->
        other
    end
  end

  def delete_issue(%Issue{} = issue) do
    result =
      issue
      |> Issue.soft_delete_changeset()
      |> Repo.update()

    case result do
      {:ok, deleted} ->
        Logger.warning("Issue soft-deleted",
          event: :issue_deleted,
          issue_id: deleted.id,
          reporter_id: deleted.reporter_id
        )

        {:ok, deleted}

      other ->
        other
    end
  end

  def get_issue(id, opts \\ []) do
    include_deleted? = Keyword.get(opts, :include_deleted, false)

    query = from i in Issue, where: i.id == ^id

    query = if include_deleted?, do: query, else: exclude_deleted(query)

    query
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.one()
  end

  def get_issue!(id, opts \\ []) do
    case get_issue(id, opts) do
      nil -> raise Ecto.NoResultsError, queryable: Issue
      issue -> issue
    end
  end

  def list_issues_for_reporter(%{id: reporter_id}, opts \\ []) do
    from(i in Issue, where: i.reporter_id == ^reporter_id)
    |> maybe_include_deleted(opts)
    |> order_by([i], desc: i.inserted_at)
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.all()
  end

  def list_issues_for_technician(%{id: technician_id}, opts \\ []) do
    from(i in Issue, where: i.assigned_technician_id == ^technician_id)
    |> maybe_include_deleted(opts)
    |> order_by([i], desc: i.inserted_at)
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.all()
  end

  def list_all_issues(opts \\ []) do
    Issue
    |> maybe_include_deleted(opts)
    |> maybe_filter_status(opts)
    |> maybe_filter_priority(opts)
    |> maybe_filter_unassigned(opts)
    |> order_by([i], desc: i.inserted_at)
    |> preload([:reporter, :apartment, :assigned_technician])
    |> Repo.all()
  end

  def change_issue_report(%Issue{} = issue \\ %Issue{}, attrs \\ %{}) do
    Issue.report_changeset(issue, attrs)
  end

  def change_issue_assign(%Issue{} = issue, attrs \\ %{}) do
    Issue.assign_changeset(issue, attrs)
  end

  defp maybe_include_deleted(query, opts) do
    if Keyword.get(opts, :include_deleted, false) do
      query
    else
      exclude_deleted(query)
    end
  end

  defp exclude_deleted(query) do
    from i in query, where: is_nil(i.deleted_at)
  end

  defp maybe_filter_status(query, opts) do
    case Keyword.get(opts, :status) do
      nil ->
        query

      status when is_atom(status) ->
        from i in query, where: i.status == ^status
    end
  end

  defp maybe_filter_priority(query, opts) do
    case Keyword.get(opts, :priority) do
      nil ->
        query

      priority when is_atom(priority) ->
        from i in query, where: i.priority == ^priority
    end
  end

  defp maybe_filter_unassigned(query, opts) do
    if Keyword.get(opts, :unassigned_only, false) do
      from i in query, where: is_nil(i.assigned_technician_id)
    else
      query
    end
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
