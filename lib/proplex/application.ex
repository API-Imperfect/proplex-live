defmodule Proplex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ProplexWeb.Telemetry,
      Proplex.Repo,
      {DNSCluster, query: Application.get_env(:proplex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Proplex.PubSub},
      {Proplex.RateLimit, [clean_period: :timer.minutes(10)]},
      # Start a worker by calling: Proplex.Worker.start_link(arg)
      # {Proplex.Worker, arg},
      # Start to serve requests, typically the last entry
      ProplexWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Proplex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ProplexWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
