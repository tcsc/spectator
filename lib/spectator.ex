defmodule Spectator do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Spectator.Multicast, [{224, 0, 0, 1}, 4475, 1, 300])
    ]

    opts = [strategy: :one_for_one, name: Spectator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
