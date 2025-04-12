defmodule SearchCache.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Registry to support dynamic, test-isolated GenServers
      {Registry, keys: :unique, name: Registry.SearchCache}

      # Optionally, you can add a default named cache here:
      # {SearchCache, name: SearchCache}
    ]

    opts = [strategy: :one_for_one, name: SearchCache.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
