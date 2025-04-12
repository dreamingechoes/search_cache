import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Optional: Configure your app environment here
# config :search_cache, ttl: 300, max_cache_size: 100
