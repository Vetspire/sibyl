defmodule Sibyl.Handlers.OpenTelemetry do
  @moduledoc """
  OpenTelemetry is an open source standard telemetry standard which allows us to capture
  custom metrics and traces of our application.

  For local development, you can install tools such as [Jaeger](https://www.jaegertracing.io/)
  to be able to view and test OpenTelemetry traces.

  However, much of the BEAM ecosystem (and this library) uses `:telemetry` as a standard
  for emitting arbitrary telemetry events.

  This handler is a bridge between standard `:telemetry` span events and OpenTelemetry
  spec compliant traces.

    - Any event which ends in `:start` will start an OpenTelemetry span context.

    - Any event which ends in `:stop` or `:exception` will stop the currently active
      OpenTelemetry span context, capturing any metadata that is passed in.

    - Any event which ends in anything else will be attached as a custom event to
      the currently active span context.

  For Elixir's built in `Task` module, `Sibyl.Handlers.OpenTelemetry` will be able to
  internal state and automatically attach said async Task to the original parent.

  Distributed traces via non `Task` means is also supported, but this cannot be automated.
  To opt into this behaviour, serialize the span state on the consumer end via the
  `build_distributed_trace_context/0` function, and *prior* to starting any new traces
  on the consumer end, use `attach_distributed_trace_context/1`. Doing this should
  attach both the consumer and producer side of the trace into one for rendering in tools
  such as Jaeger.
  """

  @behaviour Sibyl.Handler
  @dialyzer {:nowarn_function, maybe_attach_async_parent: 0, maybe_detach_async_parent: 0}

  alias OpenTelemetry.Ctx
  alias OpenTelemetry.Span
  alias OpentelemetryProcessPropagator, as: Propagator
  alias OpentelemetryTelemetry, as: Bridge

  require OpenTelemetry.Tracer, as: Tracer

  @stack {__MODULE__, :stack}
  @distributed_trace_context {__MODULE__, :distributed_trace_context}

  @doc """
  A constant for the undefined `OpenTelemetry` trace context.

  Useful for defaulting a distributed trace context parse to a "noop" if data is malformed
  or mistransmitted.
  """
  @spec undefined_trace_context :: String.t()
  def undefined_trace_context, do: "g2QACXVuZGVmaW5lZA=="

  @doc """
  Serializes the current `OpenTelemetry` trace context to allow it to be sent over-the-wire
  to external services, with the intention to re-attach the context on the consumer's end.

  This should allow you (tooling permitting) to build distributed traces across multiple
  different nodes, releases, services, etc.
  """
  @spec build_distributed_trace_context :: String.t()
  def build_distributed_trace_context do
    # coveralls-ignore-start
    :opentelemetry.get_text_map_injector()
    |> :otel_propagator_text_map.inject(%{}, &Map.put(&3, &1, &2))
    # coveralls-ignore-stop
    |> then(fn context ->
      :opentelemetry.get_text_map_extractor()
      |> :otel_propagator_text_map.extract(context, &Map.keys/1, &Map.get(&2, &1, :undefined))
      |> :erlang.term_to_binary()
      |> Base.encode64()
    end)
  end

  @doc """
  Processes a serialized `OpenTelemetry` trace context (obtained via `build_distributed_trace_context/0`)
  and persists it within the current process.

  The **next** span which is created will be automatically attached to this distributed
  trace context, allowing for the building of (tooling permitting) distributed traces
  across multiple different nodes, releases, services, etc.
  """
  @spec attach_distributed_trace_context(trace_context :: String.t()) :: :ok
  def attach_distributed_trace_context(trace_context) do
    trace_context
    |> Base.decode64!()
    |> :erlang.binary_to_term()
    |> then(&Process.put(@distributed_trace_context, &1))

    :ok
  end

  @impl Sibyl.Handler
  def handle_event(event, measurement, metadata, config) do
    event
    |> List.pop_at(length(event) - 1)
    |> do_handle_event(measurement, metadata, config)

    :ok
  end

  defp do_handle_event({:start, mfa}, measurement, metadata, config) do
    :ok = maybe_attach_async_parent()
    Bridge.start_telemetry_span(__MODULE__, Enum.join(mfa, "."), metadata, measurement)
    :ok = set_args(metadata)
    :ok = set_attributes(metadata)
    :ok = handle_callback(config, :start)
  end

  defp do_handle_event({:stop, _mfa}, measurement, metadata, config) do
    Bridge.set_current_telemetry_span(__MODULE__, metadata)
    :ok = set_attributes(measurement)
    Bridge.end_telemetry_span(__MODULE__, metadata)
    :ok = handle_callback(config, :stop)
    :ok = maybe_detach_async_parent()
  end

  defp do_handle_event({:exception, _mfa}, measurement, metadata, config) do
    # This information is required but not guaranteed to be emitted. Set some defaults
    kind = Map.get(metadata, :kind, "Sibyl - unknown kind")
    reason = Map.get(metadata, :reason, "Sibyl - unknown reason")
    exception = Map.get(metadata, :exception, nil)
    stacktrace = Map.get(metadata, :stacktrace, nil)
    duration = Map.get(measurement, :duration, 0)

    # Bootstrap and build OpenTelemetry exception span
    ctx = Bridge.set_current_telemetry_span(__MODULE__, metadata)
    status = OpenTelemetry.status(:error, to_string(reason))
    :ok = set_attributes(measurement)

    # Handle `rescue` from Elixir or `throw` from Erlang
    if is_exception(exception) do
      Span.record_exception(ctx, exception, stacktrace, duration: duration)
    else
      :otel_span.record_exception(ctx, kind, reason, stacktrace, duration: duration)
    end

    Tracer.set_status(status)
    Bridge.end_telemetry_span(__MODULE__, metadata)
    :ok = handle_callback(config, :exception)
    :ok = maybe_detach_async_parent()
  end

  defp do_handle_event({custom_event, mfa}, measurement, metadata, config) do
    event_name =
      mfa
      |> Enum.concat([custom_event])
      |> Enum.join(".")

    event_data =
      metadata
      |> Map.merge(measurement)
      |> Map.put(:event_name, event_name)

    Tracer.add_event(event_name, event_data)
    :ok = handle_callback(config, :custom)
  end

  defp maybe_attach_async_parent do
    async_parent = async_parent()
    stack = Process.get(@stack, [])
    if async_parent != :undefined and stack == [], do: Ctx.attach(async_parent)
    if async_parent != :undefined, do: Process.put(@stack, [async_parent | stack])
    :ok
  end

  defp maybe_detach_async_parent do
    async_parent = async_parent()
    stack = Process.get(@stack, [])
    if async_parent != :undefined and stack == [], do: Ctx.detach(async_parent)
    if async_parent != :undefined and stack != [], do: Process.put(@stack, tl(stack))
    :ok
  end

  defp async_parent,
    do: Process.get(@distributed_trace_context, Propagator.fetch_parent_ctx(1, :"$callers"))

  defp set_attributes(attrs), do: Enum.each(attrs, fn {k, v} -> Tracer.set_attribute(k, v) end)

  defp set_args(%{args: args}) do
    Tracer.set_attribute("args", inspect(args))
    :ok
  end

  defp set_args(_args) do
    :ok
  end

  defp handle_callback(config, state) do
    case Keyword.get(config, :callback) do
      callback when is_function(callback, 1) ->
        callback.(state)
        :ok

      _otherwise ->
        :ok
    end
  end
end
