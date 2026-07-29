defmodule Proplex.Workers.IssueReportedEmail do
  use Oban.Worker, queue: :mailers

  alias Proplex.Issues

  alias Proplex.Issues.IssueNotifier

  @impl Oban.Worker

  def perform(%Oban.Job{args: %{"issue_id" => issue_id}}) do
    case Issues.get_issue(issue_id, include_deleted: true) do
      nil ->
        {:cancel, "issue #{issue_id} not found"}

      issue ->
        case IssueNotifier.deliver_issue_reported(issue) do
          {:ok, _email} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
