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

  Automatically traced functions are available for reflection by via `Sibyl.Events.reflect/1`.
  """

  use Decorator.Define, trace: 0

  alias Sibyl.AST
  require Sibyl.Events

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
  @spec trace(function_body :: AST.ast(), ctx :: map()) :: AST.ast() | no_return()
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

  @doc false
  @spec on_definition(env :: map(), term(), atom(), [term()], AST.ast(), AST.ast()) :: AST.ast()
  def on_definition(%{module: module} = env, kind, function, args, guards, body) do
    arity = length(args)

    if has_decorate_all?(module) or has_decorate?(module, function) do
      for event <- [:start, :stop, :exception] do
        module
        |> Sibyl.Events.build_event(function, arity, event)
        |> Sibyl.Events.define_event(module)
      end
    end

    Decorator.Decorate.on_definition(env, kind, function, args, guards, body)
  end

  defp has_decorate_all?(module), do: Module.get_attribute(module, :decorate_all) != []

  defp has_decorate?(module, function) do
    module
    |> Module.get_attribute(:decorated)
    |> Enum.find(fn node ->
      is_tuple(node) && elem(node, 0) in [:def, :defp] && elem(node, 1) == function &&
        {Sibyl.Decorator, :trace, []} in elem(node, 5)
    end)
    |> is_tuple()
  end
end
