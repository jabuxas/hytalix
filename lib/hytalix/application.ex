defmodule Hytalix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HytalixWeb.Telemetry,
      Hytalix.Repo,
      {DNSCluster, query: Application.get_env(:hytalix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Hytalix.PubSub},
      # Start a worker by calling: Hytalix.Worker.start_link(arg)
      # {Hytalix.Worker, arg},
      # Start to serve requests, typically the last entry
      HytalixWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hytalix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HytalixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
