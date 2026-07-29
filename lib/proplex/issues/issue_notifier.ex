defmodule Proplex.Issues.IssueNotifier do
  import Swoosh.Email

  alias Proplex.Mailer

  @from {"Proplex", "contact@example.com"}

  # Delivers the email using the application mailer.
  def deliver_issue_reported(issue) do
    deliver(
      issue.reporter.email,
      "Your maintenance issue was received",
      """
      Hi #{handle(issue.reporter)},

      We've received your maintenance report:

        Title: #{issue.title}
        Priority: #{String.capitalize(to_string(issue.priority))}
        Unit: #{issue.apartment.building_name} . Unit #{issue.apartment.unit_number}

        Your landlord will review it and assign a technician. You'll get another email when that happens.

        View this issue:
        #{url_for_issue(issue)}

        - The Proplex team

      """
    )
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_issue_assigned(issue) do
    deliver(issue.assigned_technician.email, "You've been assigned a new maintenance issue", """

    ==============================

    Hi #{handle(issue.assigned_technician)},

    You've been assigned the following maintenance issue:

     Title: #{issue.title}
     Priority: #{String.capitalize(to_string(issue.priority))}
     Unit: #{issue.apartment.building_name} . Unit #{issue.apartment.unit_number}
     Reporter: @#{issue.reporter.username}

    Open it in your assignments list to start work:

    #{url_for_issue(issue)}

    - The Proplex team
    ==============================
    """)
  end

  def deliver_issue_resolved(issue) do
    deliver(issue.reporter.email, "Your maintenance issue was resolved", """

    ==============================

    Hi #{handle(issue.reporter)},

    Good news - your maintenance issue has been marked resolved:

     Title: #{issue.title}
     Unit: #{issue.apartment.building_name} . Unit #{issue.apartment.unit_number}
     Resolved on: #{Date.to_iso8601(issue.resolved_on)}
     Technician: @#{issue.assigned_technician.username}

    If the issue isn't actually fixed, please file a new report -
    we can't re-open resolved issues from the app.

    View this issue:
    #{url_for_issue(issue)}

    - The Proplex team
    ==============================
    """)
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

  defp url_for_issue(issue) do
    ProplexWeb.Endpoint.url() <> "/issues/#{issue.id}"
  end
end
