defmodule Membrane.HTTP.Sink.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: Membrane.HTTP.Registry},
      {Plug.Cowboy,
       scheme: :http,
       plug: Membrane.HTTP.Sink.Endpoint,
       options: [port: 4001, protocol_options: [idle_timeout: :infinity]]}
    ]

    opts = [strategy: :one_for_one, name: Membrane.HTTP.Sink.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
