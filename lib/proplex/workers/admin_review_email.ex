defmodule Proplex.Workers.AdminReviewEmail do

  use Oban.Worker, queue: :mailers

  alias Proplex.Accounts
  alias Proplex.Reports
  alias Proplex.Reports.ReportNotifier

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"report_id" => report_id, "admin_id" => admin_id}}) do
    admin = Accounts.get_user!(admin_id)
    report = Reports.get_report!(report_id)

    case ReportNotifier.deliver_admin_review(report, admin) do
      {:ok, _email} -> :ok
      {:error,reason} -> {:error, reason}
    end
  end
end
