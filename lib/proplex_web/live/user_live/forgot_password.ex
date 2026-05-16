defmodule ProplexWeb.UserLive.ForgotPassword do
  use ProplexWeb, :live_view

  alias Proplex.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <%!-- card wrapper — same style as registration and login pages --%>
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <%!-- icon seal that breaks the top edge of the card --%>
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-key" class="size-9 text-primary" />
          </div>

          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">Forgot your password?</h1>
            <p class="mt-2 text-sm text-base-content/70">
              We'll send a password reset link to your email.
            </p>
          </div>

          <.form
            for={@form}
            id="forgot_password_form"
            phx-submit="send_email"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="email"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />

            <.button phx-disable-with="Sending..." class="btn btn-primary mt-2 w-full">
              Send reset link
            </.button>
          </.form>
          <p class="mt-6 text-center text-sm text-base-content/70">
            <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
              Back to log in
            </.link>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  @impl true
  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
