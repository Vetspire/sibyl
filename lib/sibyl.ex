defmodule Sibyl do
  @moduledoc """
  Public API for `Sibyl`.

  Intended usage:

  ```elixir
  defmodule AutomaticFunctionTracingExample do
    use Sibyl

    @decorate trace()
    def hello, do: :world
  end

  defmodule AutomaticModuleTracingExample do
    use Sibyl

    define_event :big_number
    define_event :small_number

    @decorate_all trace()

    def hello, do: :world

    def foo(number) do
      if (number > 10) do
        Sibyl.emit(:big_number)
        :ok
      else
        Sibyl.emit(:small_number)
        :error
      end
    end
  end
  ```
  """

  defmacro __using__(_opts) do
    quote do
      @sibyl_telemetry_events []
      @on_definition {Sibyl.Decorator, :on_definition}

      Module.register_attribute(__MODULE__, :sibyl_telemetry_events, persist: true)

      use Sibyl.Decorator

      require Sibyl
      require Sibyl.Events
      require OpenTelemetry.Tracer

      import Sibyl.Events, only: [define_event: 1]
    end
  end

  @doc """
  Emits an event.

  When given an event with type `[atom()]`, the event is directly emitted.

  When given an event with type `atom()`, the event is emitted only after checking if
  the given event has previously been defined by the caller's module. This is done as
  a compile time check.
  """
  @spec emit(event :: Sibyl.Events.event() | atom(), measurements :: map(), metadata :: map()) ::
          Sibyl.Events.ast()
  defmacro emit(event, measurements \\ %{}, metadata \\ %{})

  defmacro emit(event, measurements, metadata) when is_list(event) do
    quote do
      Sibyl.Events.emit(
        unquote(event),
        unquote(Macro.escape(measurements)),
        unquote(Macro.escape(metadata))
      )
    end
  end

  defmacro emit(event, measurements, metadata) when is_atom(event) do
    module = __CALLER__.module

    unless Sibyl.Events.is_event(module, Sibyl.Events.build_event(module, nil, nil, event)) do
      raise ArgumentError,
        message: """
        Unknown event `#{event}`. Please ensure any events attempted to be emitted are defined in this module.
        """
    end

    quote do
      Sibyl.Events.emit(
        unquote(module),
        unquote(event),
        unquote(Macro.escape(measurements)),
        unquote(Macro.escape(metadata))
      )
    end
  end
end
