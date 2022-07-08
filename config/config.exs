import Config

config :opentelemetry,
  traces_exporter: {:otel_exporter_stdout, []}

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"

import_config "#{config_env()}.exs"
