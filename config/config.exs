use Mix.Config

config :logger,
       level: :info,
       backends: [:console]

config :honeybadger,
       app: :certstream,
       exclude_envs: [:test],
       environment_name: :prod,
       use_logger: true

# Disable connection pooling for HTTP requests
config :hackney, use_default_pool: false       