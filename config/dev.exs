import Config

config :opentelemetry,
  traces_exporter: :otlp

config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {:opentelemetry_exporter, %{endpoints: [{:http, "localhost", 55681, []}]}}
  }

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:55681"
