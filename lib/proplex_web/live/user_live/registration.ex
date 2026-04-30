defmodule ProplexWeb.UserLive.Registration do
  use ProplexWeb, :live_view

  alias Proplex.Accounts
  alias Proplex.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-user-plus" class="size-9 text-primary" />
          </div>
          <div class="mb-6 text-center">
            <h1 class="text-2xl font-semibold tracking-tight">
              Register for an account
            </h1>
            <p class="mt-2 text-sm text-base-content/70">
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
                Log in
              </.link>
              to your account now.
            </p>
          </div>

          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-debounce="400"
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

            <.input
              field={@form[:username]}
              type="text"
              label="Username"
              autocomplete="username"
              spellcheck="false"
              required
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
              Create an account
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

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})
    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply, push_navigate(socket, to: ~p"/users/check-email?#{[email: user.email]}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
