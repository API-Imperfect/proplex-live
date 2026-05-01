defmodule ProplexWeb.UserLive.CheckEmail do
  use ProplexWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm text-center">
        <div class="mb-4 inline-flex size-14 items-center justify-center rounded-full bg-primary/10">
          <.icon name="hero-envelope" class="size-7 text-primary" />
        </div>

        <.header>
          Check your email
          <:subtitle>
            We've sent a confirmation link to your inbox.
          </:subtitle>
        </.header>
        <div class="mt-8 space-y-4">
          <div class="alert alert-info">
            <div class="text-left">
              <p>
                A confirmation link was sent to
                <span :if={@email} class="font-semibold">{@email}</span>
                <span :if={!@email}>your email address</span>
              </p>
              <p class="mt-2 text-sm opacity-80">
                Click the link in the email to activate your account.
                It may take a minute to arrive - check your spam folder if you dont see it.
              </p>
            </div>
          </div>

          <p class="text-sm text-base-content/70">
            Wrong address?
            <.link navigate={~p"/users/register"} class="font-semibold text-primary hover:underline">
              Register again
            </.link>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, assign(socket, email: params["email"])}
  end
end
