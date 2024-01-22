defmodule Sibyl.Experimental do
  @moduledoc """
  This is an experimental module for Sibyl which aims to replace the `use Sibyl` macro with something that
  does not rely on the existing `decorator` library in Elixir.

  This is due to limitations in the `decorator` library which prevent us from being able to trace functions
  which define multiple function clauses with default paramters due to the way its implemented.

  This module implements the bare neccessities to get Sibyl working without the `decorator` library, and as such,
  does not intend to replace the `decorator` library in general (though it could definitely be possible in the future).

  We do this by replacing Elixir's `def` macro when defining functions to a custom one which checks if you've opted
  into function tracing. If so, then we amend the AST of the function to include tracing code before passing it back
  to Elixir's `def` macro.

  This is a very hacky way of doing things, but it seems to generally work.

  There are two notable, core differences in using `Sibyl.Experimental` over `Sibyl` for the time being:

  1) In order to trace functions, you must annotate functions with `@sibyl trace: true`. In future, we may be able to
     capture extra metadata to attach to traces via additional keyword parameters.

  2) In order to trace all functions in a module, you must `use Sibyl.Experimental, trace_all: true`. Theoretically
     any metadata attached to individual functions should still be respected.

  For reflection purposes, you can also use call `__traces__/0` on any module that uses `Sibyl.Experimental` though
  for compatibility you may prefer to continue using `Sibyl.Events.reflect/1` instead.

  """

  # coveralls-ignore-start
  # credo:disable-for-this-file Credo.Check.Readability.Specs

  defmacro __using__(opts) do
    trace_all? = Keyword.get(opts, :trace_all, false)

    quote do
      require Sibyl
      require Sibyl.Events
      require Sibyl.Experimental

      import Sibyl, only: [emit: 1, emit: 2, emit: 3, emit: 4]
      import Sibyl.Events, only: [define_event: 1]
      import Sibyl.Experimental

      import Kernel, except: [def: 2]

      Module.register_attribute(__MODULE__, :sibyl, persist: true)
      Module.register_attribute(__MODULE__, :sibyl_trace_all, persist: true)
      Module.register_attribute(__MODULE__, :sibyl_telemetry_events, persist: true)
      Module.register_attribute(__MODULE__, :traced_functions, accumulate: true, persist: true)

      @sibyl_trace_all unquote(trace_all?)
      @sibyl_telemetry_events []

      def __traces__ do
        :attributes
        |> __MODULE__.__info__()
        |> Enum.filter(fn {k, _} -> k == :traced_functions end)
        |> Map.new(fn {_, [{module, function, arity, opts}]} ->
          {{module, function, arity}, opts || []}
        end)
      end
    end
  end

  defmacro def(call, do: expr) do
    module = __CALLER__.module
    function = elem(call, 0)
    arity = call |> elem(2) |> List.wrap() |> Enum.reject(&is_nil/1) |> length()

    env = %{module: module, function: function, arity: arity, name: function}

    quote location: :keep do
      module = unquote(module)
      function = unquote(function)
      arity = unquote(arity)

      # Functions can be decorated with a `@sibyl trace: true` annotation which enables tracing
      # for the given function.
      opts = Module.get_attribute(module, :sibyl, [])
      trace? = Keyword.get(opts, :trace, false)

      # For simplicity, if a function head is already traced, we treat all sibling function heads as
      # also traced.
      #
      # TODO: In future, it might be neat to see if we can support different metadata clauses for tracing
      #       each clause.
      already_traced? =
        module
        |> Module.get_attribute(:traced_functions, [])
        |> Enum.find(&match?({module, unquote(function), unquote(arity), _opts}, &1))

      # Modules can also be traced automatically by setting `@sibyl trace_all: true` annotation.
      # This is done automatically via `use Sibyl.Experimental, trace_all: true`.
      trace_all? = Module.get_attribute(module, :sibyl_trace_all, false)

      cond do
        trace? or trace_all? ->
          Module.delete_attribute(module, :sibyl)
          Module.put_attribute(module, :traced_functions, {module, function, arity, opts})

          for event <- [:start, :stop, :exception] do
            module
            |> Sibyl.Events.build_event(function, arity, event)
            |> Sibyl.Events.define_event(module)
          end

          Kernel.def(unquote(call), do: unquote(Sibyl.Decorator.trace(expr, env)))

        already_traced? ->
          Kernel.def(unquote(call), do: unquote(Sibyl.Decorator.trace(expr, env)))

        true ->
          Kernel.def(unquote(call), do: unquote(expr))
      end
    end
  end
end
