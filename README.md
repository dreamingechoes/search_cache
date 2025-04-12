# SearchCache

A minimal, production-ready Elixir GenServer-based in-memory cache with TTL (time-to-live) support, observability via Telemetry, and a clean, well-tested public API.

This project is built to complement the article ["The Anatomy of a GenServer"](https://dreamingecho.es/blog/the-anatomy-of-a-genserver), illustrating best practices in stateful process design, fault-tolerant behavior, and real-world concurrency patterns in Elixir.

## ✨ Features

- ✅ Built on [GenServer](https://hexdocs.pm/elixir/GenServer.html) for process-based state and message handling
- 🕒 In-memory cache with configurable TTL expiration
- 🧹 FIFO eviction strategy when reaching a configurable max size
- 📊 Periodic logging of stats via `handle_info/2`
- 🛡 Built-in [Telemetry](https://hexdocs.pm/telemetry) instrumentation for monitoring
- 🧪 100% test coverage with ExUnit, including concurrent scenarios
- 🌟 Clean public API (`fetch/2`, `cache/3`, `cache_sync/3`)
- 🧱 Isolated test processes using Registry
- ✅ CI-ready with GitHub Actions + ExCoveralls for coverage reports

## 🚀 Getting Started

### 1. Clone and install dependencies

```bash
$ git clone https://github.com/your-name/search_cache.git
$ cd search_cache
$ mix deps.get
```

### 2. Run the app in IEx

```bash
$ iex -S mix
```

### 3. Use the Cache

```elixir
iex> SearchCache.cache("elixir", %{docs: ["Getting Started"]})
:ok

iex> SearchCache.fetch("elixir")
%{docs: ["Getting Started"]}
```

## ✨ Usage Example

You can embed `SearchCache` into a real app by supervising it and interacting through its public API:

```elixir
# application.ex
children = [
  {Registry, keys: :unique, name: Registry.SearchCache},
  {SearchCache, name: SearchCache}
]
```

### Dictionary Example

Suppose you’re building a multilingual dictionary lookup:

```elixir
entries = %{
  "hello" => %{es: "hola", fr: "bonjour"},
  "thanks" => %{es: "gracias", fr: "merci"}
}

# Cache the dictionary entry
SearchCache.cache("hello", Map.get(entries, "hello"))

# Fetch a translation
case SearchCache.fetch("hello") do
  nil -> "Word not found"
  result -> result[:es]  # => "hola"
end
```

This use case is great for:
- ⚡ Reducing repeated parsing or DB lookups
- 🧠 Storing complex, nested data structures per term
- 🔠 Supporting multi-language apps with low-latency access

You can also spin up named instances dynamically:

```elixir
{:ok, _pid} = SearchCache.start_link(name: {:via, Registry, {Registry.SearchCache, :my_dict}})
SearchCache.cache({:via, Registry, {Registry.SearchCache, :my_dict}}, "bye", %{es: "adiós"})
```

## 💯 Test Coverage Highlights

- ✅ Tests for all public API behaviors (sync and async)
- 🕰 TTL expiration simulated using `:sys.replace_state/2`
- 🔀 Concurrency safety ensured via `Task.async/await`
- 📅 `handle_info/2` log behavior tested with `ExUnit.CaptureIO`
- 🛡 Telemetry validation with `:telemetry.attach_many`
- 🧼 Fully isolated GenServers using `Registry` and `start_supervised!`

## 🔧 Configuration

The following parameters can be adjusted directly in `lib/search_cache.ex`:

```elixir
@ttl_seconds 300        # Cache entry TTL (in seconds)
@max_cache_size 100     # Max number of entries before eviction
@log_interval_ms 60_000 # Interval between stats logs
```

For more advanced setups, these could be passed via `start_link/1` options and stored in the GenServer state.

## 📦 Project Structure

```
search_cache/
├── lib/
│   ├── search_cache.ex             # GenServer implementation
│   └── search_cache/application.ex # Application + Registry supervisor
├── test/
│   └── search_cache_test.exs       # Full ExUnit test coverage
├── config/
│   └── config.exs                  # Environment config
├── .formatter.exs
├── .gitignore
├── LICENSE
├── mix.exs
├── README.md
└── .github/workflows/ci.yml        # CI pipeline (build + test + coverage)
```

## 🛡 Telemetry Events

The following events are emitted for observability and monitoring:

- `[:search_cache, :fetch]`
  - **Measurement**: `%{hit: true | false}`
  - **Metadata**: `%{query: string}`
  - Emitted every time a `fetch/2` call is made, indicating whether the key was found.

- `[:search_cache, :cache]`
  - **Measurement**: `%{size: integer}`
  - **Metadata**: `%{query: string}`
  - Emitted whenever an entry is cached, with current total entries.

To consume these events, use `:telemetry.attach/4` or `:telemetry.attach_many/4` like so:

```elixir
:telemetry.attach_many("logger", [
  [:search_cache, :fetch],
  [:search_cache, :cache]
], fn event, meas, meta, _config ->
  IO.inspect({event, meas, meta}, label: "[Telemetry]")
end, nil)
```

This allows you to log metrics, report to a dashboard (e.g., Prometheus or AppSignal), or trigger custom alerts.

## 🧠 Use Cases

This module can be adapted for:

- Caching expensive search or API results
- In-memory rate limiting or throttling
- Memoization of function output
- Request deduplication / response coalescing
- Lightweight state management for prototyping

## 📖 Learn More

- [Elixir GenServer Documentation](https://hexdocs.pm/elixir/GenServer.html)
- [Telemetry in Elixir](https://hexdocs.pm/telemetry/Telemetry.html)
- [Elixir Registry](https://hexdocs.pm/elixir/Registry.html)
- [ExCoveralls Docs](https://github.com/parroty/excoveralls)
