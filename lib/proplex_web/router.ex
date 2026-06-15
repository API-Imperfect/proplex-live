defmodule ProplexWeb.Router do
  use ProplexWeb, :router

  import ProplexWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ProplexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ProplexWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ProplexWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:proplex, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ProplexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ProplexWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ProplexWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    live_session :require_profiles_edit_own,
      on_mount: [
        {ProplexWeb.UserAuth, :require_authenticated},
        {ProplexWeb.UserAuthorization, {:require_permission, :profiles, :edit_own}}
      ] do
      live "/users/settings/profile", UserLive.ProfileEdit, :edit
    end

    live_session :require_apartments_view_own,
      on_mount: [
        {ProplexWeb.UserAuth, :require_authenticated},
        {ProplexWeb.UserAuthorization, {:require_permission, :apartments, :view_own}}
      ] do
      live "/users/my-apartment", UserLive.MyApartment, :show
    end

    live_session :require_issues_create,
      on_mount: [
        {ProplexWeb.UserAuth, :require_authenticated},
        {ProplexWeb.UserAuthorization, {:require_permission, :issues, :create}}
      ] do
      live "/issues/new", IssueLive.New, :new
    end

    live_session :require_issues_view_assigned,
      on_mount: [
        {ProplexWeb.UserAuth, :require_authenticated},
        {ProplexWeb.UserAuthorization, {:require_permission, :issues, :view_assigned}}
      ] do
      live "/issues/assigned", IssueLive.Assigned, :index
    end

    live_session :require_issues_view_own,
      on_mount: [
        {ProplexWeb.UserAuth, :require_authenticated},
        {ProplexWeb.UserAuthorization, {:require_permission, :issues, :view_own}}
      ] do
      live "/issues", IssueLive.Index, :index
    end

    live_session :require_issues_detail,
      on_mount: [
        {ProplexWeb.UserAuth, :require_authenticated}
      ] do
      live "/issues/:id", IssueLive.Show, :show
    end

    live_session :require_profiles_view,
      on_mount: [
        {ProplexWeb.UserAuth, :require_authenticated},
        {ProplexWeb.UserAuthorization, {:require_permission, :profiles, :view}}
      ] do
      live "/users/:username/profile", UserLive.ProfileShow, :show
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", ProplexWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ProplexWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/check-email", UserLive.CheckEmail, :show
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/users/forgot-password", UserLive.ForgotPassword, :new
      live "/users/reset-password/:token", UserLive.ResetPassword, :edit
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
