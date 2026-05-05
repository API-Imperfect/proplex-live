defmodule ProplexWeb.UserLive.Login do
  use ProplexWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-md">
        <div class="relative rounded-box border border-base-300 bg-base-200 px-6 pb-8 pt-12 sm:px-10 sm:pb-10">
          <div class="absolute -top-7 left-1/2 inline-flex size-14 -translate-x-1/2 items-center justify-center rounded-full bg-primary/10 ring-4 ring-base-100">
            <.icon name="hero-arrow-right-end-on-rectangle" class="size-9 text-primary" />
          </div>

          <div class="mb-6 text-center">
            <%= if @current_scope do %>
              <h1 class="text-2xl font-semibold tracking-tight">
                Reauthenticate
              </h1>
              <p class="mt-2 text-sm text-base-content/70">
                Please confirm your identity to continue.
              </p>
            <% else %>
              <h1 class="text-2xl font-semibold tracking-tight">
                Log in to your account
              </h1>
              <p class="mt-2 text-sm text-base-content/70">
                Don't have an account?
                <.link
                  navigate={~p"/users/register"}
                  class="font-semibold text-primary hover:underline"
                >
                  Sign up
                </.link>
              </p>
            <% end %>
          </div>

          <.form
            for={@form}
            id="login_form"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <.input
              readonly={!!@current_scope}
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              required
              phx-mounted={JS.focus()}
            />

            <.password_input
              field={@form[:password]}
              label="Password"
              autocomplete="current-password"
              required
            />

            <div class="mt-1 mb-3 flex justify-end">
              <.link
                navigate={~p"/users/forgot-password"}
                class="text-sm text-primary hover:underline"
              >
                Forgot password?
              </.link>
            </div>

            <div class="group relative">
              <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
                Log in and stay logged in
              </.button>
              <span class="pointer-events-none absolute -top-10 left-1/2 -translate-x-1/2 whitespace-nowrap rounded bg-base-300 px-3 py-1.5 text-xs text-base-content opacity-0 transition-opacity group-hover:opacity-100">
                Stay signed in even after closing the browser
              </span>
            </div>

            <div class="group relative mt-2">
              <.button class="btn btn-primary btn-soft w-full">
                Log in only this time
              </.button>
              <span class="pointer-events-none absolute -top-10 left-1/2 -translate-x-1/2 whitespace-nowrap rounded bg-base-300 px-3 py-1.5 text-xs text-base-content opacity-0 transition-opacity group-hover:opacity-100">
                Session ends when you close the browser
              </span>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
