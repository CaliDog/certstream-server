import Config

config :certstream,
       user_agent: :default,  # Defaults to "Certstream Server v{CURRENT_VERSION}"
       full_stream_url: "/full-stream",
       domains_only_url: "/domains-only",
       sns_topic_arn: System.get_env("SNS_TOPIC_ARN")

config :logger,
       level: String.to_atom(System.get_env("LOG_LEVEL") || "info"),
       backends: [:console]

config :honeybadger,
       app: :certstream,
       exclude_envs: [:test],
       environment_name: :prod,
       use_logger: true

# Disable connection pooling for HTTP requests
config :hackney, use_default_pool: false

# AWS Configuration for SNS
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  security_token: [{:system, "AWS_SESSION_TOKEN"}, :instance_role],
  region: System.get_env("AWS_REGION") || "us-east-1"
