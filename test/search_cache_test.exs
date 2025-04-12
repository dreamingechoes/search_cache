defmodule SearchCacheTest do
  @moduledoc """
  Test suite for the `SearchCache` GenServer.

  Covers:
  - Fetching missing or cached values
  - TTL expiration
  - Cache eviction when exceeding size limit
  - Concurrent safety
  - Telemetry assertions
  """

  use ExUnit.Case, async: true

  defmodule TelemetryHandler do
    @moduledoc """
    Simple telemetry handler that forwards received events to the test process.
    Used to verify that telemetry signals were emitted as expected.
    """
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  setup do
    test_pid = self()
    name = {:via, Registry, {Registry.SearchCache, test_pid}}

    # Attach test process as telemetry handler to receive :fetch and :cache events
    :telemetry.attach_many(
      "test-tracker",
      [
        [:search_cache, :fetch],
        [:search_cache, :cache]
      ],
      &TelemetryHandler.handle_event/4,
      test_pid
    )

    # Start a unique, named GenServer per test
    start_supervised!({SearchCache, name: name})

    on_exit(fn ->
      :telemetry.detach("test-tracker")
    end)

    {:ok, name: name}
  end

  # Retry loop to wait for async telemetry events
  defp wait_for_telemetry(event_type, query, retries \\ 5)

  defp wait_for_telemetry(_type, query, 0),
    do: flunk("Telemetry event not received in time for query: #{inspect(query)}")

  defp wait_for_telemetry(event_type, query, retries) do
    receive do
      {:telemetry_event, ^event_type, _measurements, %{query: ^query}} -> :ok
    after
      150 -> wait_for_telemetry(event_type, query, retries - 1)
    end
  end

  # Helper functions to reduce verbosity
  defp fetch(name, query), do: GenServer.call(name, {:fetch, query})
  defp cache_sync(name, query, result), do: GenServer.call(name, {:cache_sync, query, result})

  @tag :telemetry
  test "returns nil for a missing query", %{name: name} do
    assert fetch(name, "elixir") == nil
    wait_for_telemetry([:search_cache, :fetch], "elixir")
  end

  test "caches and fetches a result", %{name: name} do
    result = %{docs: ["Elixir Guide"]}
    :ok = cache_sync(name, "elixir", result)
    assert fetch(name, "elixir") == result
    wait_for_telemetry([:search_cache, :cache], "elixir")
    wait_for_telemetry([:search_cache, :fetch], "elixir")
  end

  test "evicts entries after TTL", %{name: name} do
    result = %{docs: ["Old"]}
    :ok = cache_sync(name, "ttl_test", result)
    Process.sleep(10)

    # Manually expire the entry
    pid = GenServer.whereis(name)
    assert is_pid(pid)

    :sys.replace_state(pid, fn state ->
      Map.update!(state, "ttl_test", fn {val, _ts} -> {val, System.system_time(:second) - 301} end)
    end)

    assert fetch(name, "ttl_test") == nil
    wait_for_telemetry([:search_cache, :fetch], "ttl_test")
  end

  test "evicts oldest when max size is reached", %{name: name} do
    for i <- 1..101 do
      cache_sync(name, "q#{i}", %{i: i})
    end

    # Oldest (q1) should be evicted
    assert fetch(name, "q1") == nil
    assert fetch(name, "q101") == %{i: 101}
  end

  test "handles concurrent access safely", %{name: name} do
    tasks =
      for i <- 1..20 do
        Task.async(fn ->
          cache_sync(name, "key_#{i}", %{data: i})
        end)
      end

    Enum.each(tasks, &Task.await(&1, 500))

    for i <- 1..20 do
      assert fetch(name, "key_#{i}") == %{data: i}
    end
  end
end
