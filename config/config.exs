use Mix.Config

config :certstream,
       user_agent: :default  # Defaults to "Certstream Server v{CURRENT_VERSION}"

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
