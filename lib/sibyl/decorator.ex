defmodule Sibyl.Decorator do
  @moduledoc """
  Module encapsulating Sibyl's business logic for decorating functions for automated
  tracing.

  Should be used only via `use Sibyl`.

  When used like this, provides the ability to decorate your function calls with:

  - `@decorate trace()` to automatically trace a single function's execution, emitting
    telemetry events for `:start`, `:end`, and `:exception` sub-events.

  - `@decorate_all trace()` which does the same as the above, but automatically for
    all functions in a module.

  Automatically traced functions are available for reflection by via `Sibyl.reflect/1`.
  """

  use Decorator.Define, trace: 0
  require Sibyl.Events

  @type ast() :: term()

  @doc """
  Decorator which wraps a given function with a standard telemetry span.

  The name of the captured event will be determined by however `Sibyl` is configured
  to generate event names.

  Due to how anonymous functions are defined and executed in the BEAM, it ends up
  being quite a bit more performant to build the span manually rather than using
  `:telemetry.span/3`.

  See [here](https://keathley.io/blog/telemetry-conventions.html) for an example of
  how to emit the correct events.

  See [here](https://github.com/beam-telemetry/telemetry/pull/43) for explanations
  w.r.t. anonymous function perf.
  """
  @spec trace(function_body :: ast(), ctx :: map()) :: ast() | no_return()
  def trace(body, ctx) do
    Application.ensure_all_started(:telemetry)
    event = Sibyl.Events.build_event(ctx.module, ctx.name, ctx.arity)

    quote do
      event = unquote(event)

      args = unquote(ctx.args)
      module = unquote(inspect(ctx.module))
      function = unquote(ctx.name)
      arity = unquote(ctx.arity)

      metadata = %{
        args: args,
        module: module,
        function: function,
        arity: arity,
        mfa: "#{module}.#{function}/#{arity}",
        node: node()
      }

      start_system_time = System.system_time()
      start_monotonic_time = System.monotonic_time()

      Sibyl.Events.emit(
        event ++ [:start],
        %{system_time: start_system_time, monotonic_time: start_monotonic_time},
        metadata
      )

      result =
        try do
          unquote(body)
        rescue
          exception ->
            exception_type = Map.get(exception, :__struct__, Sibyl.UnknownExceptionType)
            rescue_monotonic_time = System.monotonic_time()

            Sibyl.Events.emit(
              event ++ [:exception],
              %{
                duration: rescue_monotonic_time - start_monotonic_time,
                monotonic_time: rescue_monotonic_time
              },
              Map.merge(metadata, %{
                kind: :rescue,
                reason: exception_type,
                exception: exception,
                stacktrace: __STACKTRACE__
              })
            )

            reraise exception, __STACKTRACE__
        catch
          kind, reason ->
            catch_monotonic_time = System.monotonic_time()

            Sibyl.Events.emit(
              event ++ [:exception],
              %{
                duration: catch_monotonic_time - start_monotonic_time,
                monotonic_time: catch_monotonic_time
              },
              Map.merge(metadata, %{kind: kind, reason: reason, stacktrace: __STACKTRACE__})
            )

            :erlang.raise(kind, reason, __STACKTRACE__)
        end

      stop_monotonic_time = System.monotonic_time()

      Sibyl.Events.emit(
        event ++ [:stop],
        %{
          duration: stop_monotonic_time - start_monotonic_time,
          monotonic_time: stop_monotonic_time
        },
        metadata
      )

      result
    end
  end

  @doc """
  INTERNAL: Not intended for public use, but interesting nevertheless.

  Arjan's `Decorator` library gets us 99% of the way to being to easily automate
  the tracing of functions in our modules.

  However: Arjan cleans up any hint that `Decorator` was used in his `on_definition/6`
  callback, which prevents us from knowing what functions were decorated after
  compile time.

  This is fine, except to use these events with `:telemetry`, we have to explicitly
  handle these events.

  As event names are dynamic at compile time, we want to be able to say something
  like: `Sibyl.list_decorated_function_event_names/1` given a module.

  To do this, we override Arjan's `on_definition` function and persist a custom
  `@dynamic_telemetry_events` module attribute which we can refer to later on
  before delegating back to Arjan's original `on_definition` function.

  NOTE: actually runs function by function :-) keep note of this!
  """
  @spec on_definition(env :: map(), term(), atom(), list(term()), ast(), ast()) :: ast()
  def on_definition(%{module: module} = env, kind, function, args, guards, body) do
    arity = length(args)

    if has_decorators?(module) do
      for event <- [:start, :stop, :exception] do
        module
        |> Sibyl.Events.build_event(function, arity, event)
        |> Sibyl.Events.define_event(module)
      end
    end

    Decorator.Decorate.on_definition(env, kind, function, args, guards, body)
  end

  defp has_decorators?(module) do
    Module.get_attribute(module, :decorate) ++
      Module.get_attribute(module, :decorate_all) != []
  end
end
