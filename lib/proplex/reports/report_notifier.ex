defmodule Proplex.Reports.ReportNotifier do

  import Swoosh.Email

  alias Proplex.Mailer
  alias Proplex.Reports.Report

  @from {"Proplex", "contact@example.com"}

  def deliver_report_warning(%Report{} = report) do
    deliver(
      report.reported.email,
      "A report has been filed against your account",

      """
       Hi #{handle(report.reported)},

       Another tenant has filed a misconduct report about your conduct in the building. This is an automated heads-up - no action has been taken on your account.

       Category: #{Report.category_label(report.category)}

       What to do next:


       • Take a moment to review the community rules:
         #{rules_url()}


       • If you believe this was filed in error, reply to this email
         with a brief explanation. Your property admin reads every
         reply and will follow up directly.


       • Please don't try to identify or confront the other tenant.
         Reports are confidential, and admins are the right path for
         anything that needs a response.


     — The Proplex team
     """
    )
  end

  def deliver_admin_review(%Report{}=report, admin) do
    deliver(
      admin.email,
      "User @#{report.reported.username} flagged for review",

      """
      Hi #{handle(admin)},

      @#{report.reported.username} has reached the report threshold
     and has been flagged for admin review. No enforcement action
     has been taken automatically — the account remains active
     until an admin decides otherwise.

     Latest report:
       From: @#{report.reporter.username}
       Category: #{Report.category_label(report.category)}
       Title: #{report.title}

    Review the flagged user:
    #{admin_user_url(report.reported)}

    - The Proplex team

      """
    )
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(@from)
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp handle(%{username: username}) when is_binary(username), do: username
  defp handle(user), do: user.email

  defp rules_url do
    ProplexWeb.Endpoint.url() <> "/rules"
  end

  defp admin_user_url(user) do
    ProplexWeb.Endpoint.url() <> "/admin/users/#{user.id}/edit"
  end

end
