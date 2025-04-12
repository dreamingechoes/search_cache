defmodule SearchCache do
  @moduledoc """
  `SearchCache` is an in-memory caching GenServer designed to store recent search results.

  ### Key Features:
  - Stores results in a simple key-value map: `%{query_string => {result, timestamp}}`
  - Applies a configurable TTL (time-to-live) to each entry (default: 5 minutes)
  - Evicts the oldest entry when a configurable size limit is exceeded (default: 100 entries)
  - Emits [Telemetry](https://hexdocs.pm/telemetry/) events for `:fetch` and `:cache`
  - Logs cache statistics to stdout at a fixed interval (default: every 60 seconds)
  - Supports named instances for isolation (e.g. in tests or multitenant use)

  ### Use Cases:
  - Avoid expensive or repeated API/database calls for the same search queries
  - Lightweight and self-contained cache that runs as a supervised OTP process
  - Can be scaled by spinning up multiple named instances using Elixir Registry

  This module is well suited for use in Phoenix or any Elixir app that requires a TTL cache
  with bounded size and simple observability.
  """

  use GenServer

  @max_cache_size 100
  @ttl_seconds 300
  @log_interval_ms 60_000

  @type state :: %{optional(String.t()) => {any(), integer()}}

  ## Public API

  @doc """
  Starts the SearchCache GenServer process.

  ## Options
    - `:name` - Optional name for registration (atom or `{:via, Registry, ...}` tuple).
      Defaults to `__MODULE__`.

  Typically supervised via `start_link/1` in your application's supervision tree.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc """
  Fetch a cached result by query.

  Returns the cached result if present and not expired, or `nil` otherwise.
  Also emits a `[:search_cache, :fetch]` Telemetry event.
  """
  @spec fetch(pid() | atom(), String.t()) :: any() | nil
  def fetch(server, query), do: GenServer.call(server, {:fetch, query})

  @doc """
  Asynchronously store a result for the given query.

  Does not return a response, use for fire-and-forget caching.
  Emits a `[:search_cache, :cache]` Telemetry event.
  """
  @spec cache(pid() | atom(), String.t(), any()) :: :ok
  def cache(server, query, result), do: GenServer.cast(server, {:cache, query, result})

  @doc """
  Synchronously store a result for the given query.

  Ensures the value is cached before continuing. Mainly used in tests.
  Emits a `[:search_cache, :cache]` Telemetry event.
  """
  @spec cache_sync(pid() | atom(), String.t(), any()) :: :ok
  def cache_sync(server, query, result), do: GenServer.call(server, {:cache_sync, query, result})

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    schedule_log()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:fetch, query}, _from, state) do
    now = System.system_time(:second)

    case Map.get(state, query) do
      {value, timestamp} when now - timestamp < @ttl_seconds ->
        :telemetry.execute([:search_cache, :fetch], %{hit: true}, %{query: query})
        {:reply, value, state}

      _ ->
        :telemetry.execute([:search_cache, :fetch], %{hit: false}, %{query: query})
        {:reply, nil, Map.delete(state, query)}
    end
  end

  @impl true
  def handle_call({:cache_sync, query, result}, _from, state) do
    now = System.system_time(:second)

    new_state =
      state
      |> maybe_evict()
      |> Map.put(query, {result, now})

    :telemetry.execute([:search_cache, :cache], %{size: map_size(new_state)}, %{query: query})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:cache, query, result}, state) do
    now = System.system_time(:second)

    new_state =
      state
      |> maybe_evict()
      |> Map.put(query, {result, now})

    :telemetry.execute([:search_cache, :cache], %{size: map_size(new_state)}, %{query: query})
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:log_stats, state) do
    IO.puts("[Cache Stats] Entries: #{map_size(state)}")
    schedule_log()
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp schedule_log do
    Process.send_after(self(), :log_stats, @log_interval_ms)
  end

  defp maybe_evict(state) when map_size(state) >= @max_cache_size do
    [oldest | _] = state |> Map.keys() |> Enum.sort()
    Map.delete(state, oldest)
  end

  defp maybe_evict(state), do: state
end
