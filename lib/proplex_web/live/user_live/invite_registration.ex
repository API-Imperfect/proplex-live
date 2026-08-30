defmodule ProplexWeb.UserLive.InviteRegistration do
  use ProplexWeb, :live_view

  alias Proplex.Accounts
  alias Proplex.Accounts.User
  alias Proplex.Apartments

  @impl true
  def render(%{pending_tenancy: nil} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-exclamation-triangle" class="size-9 text-warning" />
          </div>

          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">
              Invite not valid
            </h1>
            <p class="mt-2 text-sm text-base-content/70">
              This invite link is invalid or has expired. Please ask your landlord to send a new one.

            </p>
          </div>

          <div class="text-center text-sm">
            <.link navigate={~p"/users/log-in"} class="text-primary hover:underline">
                Already have an account? Log in
              </.link>

          </div>
      </div>
      </div>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-key" class="size-9 text-primary" />
          </div>

          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">
              Accept your invite
            </h1>
            <p class="mt-2 text-sm text-base-content/70">
              You've been invited to join Proplex for <strong>
              {@pending_tenancy.apartment.building_name} · Unit
              {@pending_tenancy.apartment.unit_number}
              </strong>

            </p>
            <p class="mt-1 text-xs text-base-content/60">
              Move-in date: {Calendar.strftime(@pending_tenancy.start_date,"%B %-d, %Y" )}
            </p>
          </div>

          <.form
            for={@form}
            id="invite_registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-debounce="400"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              value={@pending_tenancy.invite_email}
              readonly
              autocomplete="email"
            />

            <.input
              field={@form[:username]}
              type="text"
              label="Pick a username"
              autocomplete="username"
              spellcheck="false"
              required
             phx-mounted={JS.focus()}
            />

            <.password_input
              field={@form[:password]}
              label="Password"
              autocomplete="new-password"
              required
              phx-debounce="blur"
            />

            <p class="-mt-1 mb-3 text-xs text-base-content/60">
              At least 12 characters.
            </p>

            <.password_input
              field={@form[:password_confirmation]}
              label="Confirm Password"
              autocomplete="new-password"
              required
              phx-debounce="blur"
            />

            <.button phx-disable-with="Creating account..." class="btn btn-primary mt-2 w-full">
              Create account
            </.button>
          </.form>
      </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ProplexWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(%{"token" => raw_token}, _session, socket) do
    pending = Apartments.get_pending_tenancy_by_token(raw_token)

    if pending do
       changeset = Accounts.change_user_registration(%User{},
       %{"email" => pending.invite_email})

       {:ok, socket
        |> assign(:pending_tenancy, pending)
        |> assign(:raw_token, raw_token)
        |> assign_form(changeset),
        temporary_assigns: [form: nil]}

    else
      {:ok, assign(socket, :pending_tenancy, nil)}
    end

  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Apartments.accept_invite(socket.assigns.pending_tenancy, user_params) do

      {:ok, _user, _tenancy} ->
        {:noreply,
      socket
    |> put_flash(
      :info,
      "Account created and linked to your apartment. Please log in to continue."
    )
    |> push_navigate(to: ~p"/users/log-in")
  }

  {:error, %Ecto.Changeset{} = changeset} ->

       {:noreply, assign_form(socket, changeset)}


     {:error, {step, _value}} ->

       {:noreply,
        socket
        |> put_flash(
          :error,
          "Couldn't complete registration (#{inspect(step)} step failed). Please try again or ask your landlord to resend the invite."
        )}

    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket,changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
