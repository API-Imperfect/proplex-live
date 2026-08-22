defmodule Proplex.Apartments.InviteNotifier do
  import Swoosh.Email
  alias Proplex.Mailer

  @from {"Proplex", "contact@example.com"}

  def deliver_invite(pending_tenancy, raw_token) when is_binary(raw_token) do
    apartment = pending_tenancy.apartment

    deliver(
      pending_tenancy.invite_email,
     "You're invited to join #{apartment.building_name} · Unit #{apartment.unit_number} on Proplex",

     """


     Hi there,


     Your landlord has invited you to join Proplex — the apartment
     community management app — for:


       #{apartment.building_name} · Unit #{apartment.unit_number} (Floor #{apartment.floor})
       Move-in date: #{Date.to_iso8601(pending_tenancy.start_date)}


     To accept the invite and create your account:


       #{invite_url(raw_token)}


     This link expires on #{Calendar.strftime(pending_tenancy.expires_at, "%B %-d, %Y at %H:%M UTC")}.
     Once it expires, ask your landlord to resend the invite.


     If you weren't expecting this invitation, you can safely ignore
     this email — no account will be created.


     — The Proplex team
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

  defp invite_url(raw_token) do
    ProplexWeb.Endpoint.url() <> "/users/invite/#{raw_token}"
  end
end
