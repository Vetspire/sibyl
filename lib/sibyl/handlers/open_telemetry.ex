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

  Distributed traces are also captured and linked together for calls which originate via
  Elixir's `Task` module.

  More work will be done in the future to allow users of `Sibyl` to hook into, and manually
  link parent traces.
  """

  @behaviour Sibyl.Handler
  @dialyzer {:nowarn_function, maybe_attach_async_parent: 0, maybe_detach_async_parent: 0}

  alias OpenTelemetry.Ctx
  alias OpenTelemetry.Span
  alias OpentelemetryProcessPropagator, as: Propagator
  alias OpentelemetryTelemetry, as: Bridge

  require OpenTelemetry.Tracer, as: Tracer

  @stack {__MODULE__, :stack}

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
    if Exception.exception?(exception) do
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
    async_parent = Propagator.fetch_parent_ctx(1, :"$callers")
    stack = Process.get(@stack, [])
    if async_parent != :undefined and stack == [], do: Ctx.attach(async_parent)
    if async_parent != :undefined, do: Process.put(@stack, [async_parent | stack])
    :ok
  end

  defp maybe_detach_async_parent do
    async_parent = Propagator.fetch_parent_ctx(1, :"$callers")
    stack = Process.get(@stack, [])
    if async_parent != :undefined and stack == [], do: Ctx.detach(async_parent)
    if async_parent != :undefined, do: Process.put(@stack, tl(stack))
    :ok
  end

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
