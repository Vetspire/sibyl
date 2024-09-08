defmodule Sibyl.Decorator do
  @moduledoc """
  Module encapsulating Sibyl's business logic for decorating functions for automated
  tracing.

  Should be used only via `use Sibyl`.

  When used like this, provides the ability to decorate your function calls with:

  - `@decorate trace()` to automatically trace a single function's execution, emitting
    telemetry events for `:start`, `:end`, and `:exception` sub-events.

  - `@decorate_all trace()` which does the same as the above, but automatically for
    all functions in a module (except functions that starts with `_`).

  Automatically traced functions are available for reflection by via `Sibyl.Events.reflect/1`.
  """

  use Decorator.Define, trace: 0, trace: 1

  alias Sibyl.AST
  require Sibyl.Events

  @doc """
  Decorator which wraps a given function with a standard telemetry span.

  The name of the captured event will be determined by however `Sibyl` is configured
  to generate event names.

  ## Opts

  - `:only` – will decorate only specified functions;
  - `:except` – will decorate all functions except specified functions.

  Functions are specified as `{name, arity}` tuples, `arity` can be `:*` to specify any arity.

  ## Notes

  Due to how anonymous functions are defined and executed in the BEAM, it ends up
  being quite a bit more performant to build the span manually rather than using
  `:telemetry.span/3`.

  See [here](https://keathley.io/blog/telemetry-conventions.html) for an example of
  how to emit the correct events.

  See [here](https://github.com/beam-telemetry/telemetry/pull/43) for explanations
  w.r.t. anonymous function perf.
  """
  @spec trace(opts, function_body :: AST.ast(), ctx :: map()) :: AST.ast() | no_return()
        when fun_arity: {name :: atom(), arity :: non_neg_integer() | :*},
             opts: {:only | :except, [fun_arity]}
  def trace(opts \\ [], body, ctx) do
    if should_decorate?(opts, ctx) do
      do_decorate(body, ctx)
    else
      body
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

  defp do_decorate(body, ctx) do
    Application.ensure_all_started(:telemetry)
    event = Sibyl.Events.build_event(ctx.module, ctx.name, ctx.arity)

    quote do
      args = binding() |> Keyword.values() |> Enum.reverse()

      event = unquote(event)
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

      start = :os.perf_counter()

      :ok = Sibyl.Events.emit(unquote(event ++ [:start]), %{timestamp: start}, metadata)

      result =
        try do
          unquote(body)
        rescue
          exception ->
            exception_type = Map.get(exception, :__struct__, Sibyl.UnknownExceptionType)
            stop = :os.perf_counter()

            :ok =
              Sibyl.Events.emit(
                unquote(event ++ [:exception]),
                %{duration: stop - start, timestamp: stop},
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
            stop = :os.perf_counter()

            :ok =
              Sibyl.Events.emit(
                unquote(event ++ [:exception]),
                %{duration: stop - start, timestamp: stop},
                Map.merge(metadata, %{kind: kind, reason: reason, stacktrace: __STACKTRACE__})
              )

            :erlang.raise(kind, reason, __STACKTRACE__)
        end

      stop = :os.perf_counter()

      :ok =
        Sibyl.Events.emit(
          unquote(event ++ [:stop]),
          %{duration: stop - start, timestamp: stop},
          metadata
        )

      result
    end
  end

  defp should_decorate?(opts, %{name: name, arity: arity}) do
    cond do
      opts[:only][name] in [:*, arity] -> true
      opts[:only] -> false
      opts[:except][name] in [:*, arity] -> false
      name |> to_string() |> String.starts_with?("_") -> false
      true -> true
    end
  end

  defp has_decorate_all?(module), do: Module.get_attribute(module, :decorate_all) != []

  defp has_decorate?(module, function) do
    module
    |> Module.get_attribute(:decorated)
    |> Enum.find(fn node ->
      is_tuple(node) && elem(node, 0) in [:def, :defp] && elem(node, 1) == function &&
        Enum.any?(elem(node, 5), &match?({Sibyl.Decorator, :trace, _}, &1))
    end)
    |> is_tuple()
  end
end
