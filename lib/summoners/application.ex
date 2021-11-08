defmodule Summoners.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      SummonersWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Summoners.PubSub},
      # Start the Endpoint (http/https)
      SummonersWeb.Endpoint,
      # Start a worker by calling: Summoners.Worker.start_link(arg)
      # {Summoners.Worker, arg}
      {Finch, name: Riot},
      Summoners.RiotApi.Cache,
      Summoners.Cache,
      {Task.Supervisor, name: Summoners.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Summoners.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SummonersWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
