defmodule Proplex.Workers.ReportWarningEmail do

  use Oban.Worker, queue: :mailers

  alias Proplex.Reports
  alias Proplex.Reports.ReportNotifier

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"report_id" => report_id}}) do
    report = Reports.get_report!(report_id)

    case ReportNotifier.deliver_report_warning(report) do
      {:ok, _email} -> :ok
      {:error,reason} -> {:error, reason}
    end
  end

end
