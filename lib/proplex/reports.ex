defmodule Proplex.Reports do
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias Proplex.Repo
  alias Proplex.RateLimit
  alias Proplex.Accounts.{Profile, User}
  alias Proplex.Apartments
  alias Proplex.Apartments.{Apartment, Tenancy}
  alias Proplex.Authorization
  alias Proplex.Reports.Report
  alias Proplex.Workers.{AdminReviewEmail, ReportWarningEmail}

  @warning_threshold 3

  @flag_threshold 5

  @reputation_penalty_per_report 20

  def flag_threshold, do: @flag_threshold

  def warning_threshold, do: @warning_threshold

  def get_report!(id) do
    Report
    |> Repo.get!(id)
    |> Repo.preload([:reporter, :reported])
  end

  def change_report(%Report{} = report \\ %Report{}, attrs \\ %{}) do
    Report.create_changeset(report, attrs)
  end

  def create_report(%User{} = reporter, attrs, opts \\ []) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("reporter_id", reporter.id)

    with :ok <- ensure_reportable(reporter, attrs["reported_id"]),
         :ok <- maybe_check_rate_limit(reporter, opts),
         {:ok, %{report: report, profile: profile}} <- run_create_multi(attrs) do
      escalation = determine_escalation(profile)

      Logger.info("Report filed",
        event: :report_filed,
        report_id: report.id,
        reporter_id: report.reporter_id,
        reported_id: report.reported_id,
        category: to_string(report.category),
        report_count: profile.report_count
      )

      enqueue_escalation_emails(report, escalation)

      {:ok, report, escalation}
    end
  end

  defp ensure_reportable(_reporter, blank) when blank in [nil, ""], do: :ok

  defp ensure_reportable(%User{} = reporter, reported_id) do
    with {:ok, reported_id} <- parse_id(reported_id),
         {:ok, _apartment, neighbors} <- list_reportable_neighbors(reporter),
         true <- Enum.any?(neighbors, &(&1.user_id == reported_id)) do
      :ok
    else
      {:error, :no_active_apartment} -> {:error, :no_active_apartment}
      _ -> {:error, :not_reportable}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_id(_id), do: :error

  defp maybe_check_rate_limit(%User{id: user_id}, opts) do
    if Keyword.get(opts, :skip_rate_limit, false) do
      :ok
    else
      case RateLimit.record_report_attempt(user_id) do
        :ok -> :ok
        {:deny, retry_after_ms} -> {:error, :rate_limited, retry_after_ms}
      end
    end
  end

  defp run_create_multi(attrs) do
    Multi.new()
    |> Multi.insert(:report, Report.create_changeset(%Report{}, attrs))
    |> Multi.run(:locked_profile, fn repo, %{report: report} ->
      lock_profile(repo, report.reported_id)
    end)
    |> Multi.update(:profile, fn %{locked_profile: profile} ->
      apply_report_penalty(profile)
    end)
    |> Multi.run(:flagged_user, fn repo, %{report: report, profile: profile} ->
      maybe_flag_user(repo, report.reported_id, profile)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, changes} -> {:ok, changes}
      {:error, _step, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  defp lock_profile(repo, user_id) do
    query = from p in Profile, where: p.user_id == ^user_id, lock: "FOR UPDATE"

    case repo.one(query) do
      nil -> {:error, :profile_not_found}
      %Profile{} = profile -> {:ok, profile}
    end
  end

  defp apply_report_penalty(%Profile{} = profile) do
    Ecto.Changeset.change(profile,
      report_count: profile.report_count + 1,
      reputation: max(profile.reputation - @reputation_penalty_per_report, 0)
    )
  end

  defp maybe_flag_user(repo, user_id, %Profile{report_count: count})
       when count >= @flag_threshold do
    case repo.get!(User, user_id) do
      %User{flagged_at: nil} = user -> user |> User.flag_changeset() |> repo.update()
      %User{} = already_flagged -> {:ok, already_flagged}
    end
  end

  defp maybe_flag_user(_repo, _user_id, _profile), do: {:ok, nil}

  defp determine_escalation(%Profile{report_count: @flag_threshold}), do: :admin_review_triggered
  defp determine_escalation(%Profile{report_count: @warning_threshold}), do: :warning_triggered
  defp determine_escalation(%Profile{}), do: :no_escalation

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp enqueue_escalation_emails(report, :warning_triggered) do
    %{report_id: report.id}
    |> ReportWarningEmail.new()
    |> Oban.insert()

    :ok
  end

  defp enqueue_escalation_emails(report, :admin_review_triggered) do
    "admin"
    |> Authorization.list_users_with_role()
    |> Enum.each(fn admin ->
      %{report_id: report.id, admin_id: admin.id}
      |> AdminReviewEmail.new()
      |> Oban.insert()
    end)

    :ok
  end

  defp enqueue_escalation_emails(_report, :no_escalation), do: :ok

  def list_reportable_neighbors(%User{id: reporter_id} = reporter) do
    case Apartments.get_current_apartment_for_user(reporter) do
      nil ->
        {:error, :no_active_apartment}

      %Apartment{} = reporter_apt ->
        already_reported_ids =
          Repo.all(
            from r in Report,
              where: r.reporter_id == ^reporter_id,
              select: r.reported_id
          )

        rows =
          from(a in Apartment,
            join: t in Tenancy,
            on: t.apartment_id == a.id and is_nil(t.end_date),
            join: u in User,
            on: u.id == t.user_id,
            left_join: p in Profile,
            on: p.user_id == u.id,
            where: a.building_name == ^reporter_apt.building_name,
            where: a.id != ^reporter_apt.id,
            where: is_nil(a.archived_at),
            where: u.id != ^reporter_id,
            where: u.id not in ^already_reported_ids,
            order_by: a.unit_number,
            select: %{
              apartment_id: a.id,
              unit_number: a.unit_number,
              floor: a.floor,
              user_id: u.id,
              username: u.username,
              first_name: p.first_name,
              last_name: p.last_name
            }
          )
          |> Repo.all()

        {:ok, reporter_apt, rows}
    end
  end
end
