defmodule ProplexWeb.UserLive.ResetPassword do
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
            <h1 class="text-2xl font-semibold tracking-tight">Reset your password</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Enter your new password below.
            </p>
          </div>

          <.form
            for={@form}
            id="reset_password_form"
            phx-submit="reset_password"
            phx-change="validate"
            phx-debounce="400"
          >
            <.password_input
              field={@form[:password]}
              label="New password"
              autocomplete="new-password"
              required
              phx-mounted={JS.focus()}
            />
            <p class="-mt-1 mb-3 text-xs text-base-content/60">At least 12 characters.</p>

            <.password_input
              field={@form[:password_confirmation]}
              label="Confirm new password"
              autocomplete="new-password"
              required
              phx-debounce="blur"
            />

            <.button phx-disable-with="Resetting..." class="btn btn-primary mt-2 w-full">
              Reset password
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
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      changeset = Accounts.change_user_password(user)

      {:ok, socket |> assign(user: user, token: token) |> assign_form(changeset)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Reset password link is invalid or it has expired")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_password(socket.assigns.user, user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully. Please log in.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end
end
