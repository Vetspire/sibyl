defmodule Sibyl do
  @moduledoc """
  Sibyl is a library which augments the BEAM's default tracing capabilities by hooking
  into `:telemetry`, `:dbg` (the BEAM's built in tracing and debugging functionality),
  and `OpenTelemetry`.

  ## Basic Usage

  To leverage all that Sibyl gives you, you need to use it in a module like so:

  ```elixir
  defmodule MyApp.Users do
    use Sibyl
  end
  ```

  Following this, you're able to begin emitting telemetry events and tracing function
  execution.

  ### Tracing Function Execution

  Sibyl provides two decorators which you can use in your modules to automatically
  trace function execution. These are `@decorate_all trace()` and `@decorate trace()`,
  which automatically traces _all_ functions in the given module, or the function
  most immediately following the decorator respectively.

  Sibyl's function tracing follows `:telemetry`'s standard specification for capturing
  spans. At the beginning of a function a `:start` event is emitted; and at the end
  of a function a `:stop` event is emitted. If an exception (arising from a `raise`
  or `throw`) is detected, an `:exception` event is emitted instead.

  Unlike `:telemetry.span/3` however, Sibyl's trace decorators inline these event
  emissions into the compiled bytecode of your module, which is slightly more efficient
  than wrapping traces within anonymous functions. This also has the benefit of making
  stacktraces easier to read.

  Event names are automatically determined such that a `:start` event is emitted by
  the function `MyApp.Users.sign_up`; the `[:my_app, :users, :sign_up, :start]` event
  is emitted.

  Examples follow:

  ```elixir
  defmodule MyApp.Users do
    use Sibyl

    @decorate trace()
    def sign_up(attrs) do
      :ok
    end
  end

  defmodule MyApp.Mailer do
    use Sibyl

    @decorate_all trace()

    def build_mail(attrs) do
      :ok
    end

    def send_mail(attrs) do
      attrs
      |> build_mail()
      |> handle_send()
    end
  end
  ```

  ### Custom Event Emission

  Sibyl also provides a thin wrapper over `:telemetry.execute/3` to make event emission
  less error prone.

  Sibyl will perform compile time checks prior to attempting to emit an event to make
  sure that it has previously been defined in the current module.

  Thus, it is important to explicitly define events prior to emission, which adds
  much needed safety when dealing with needing to change/rename events.

  Events which are defined in a module are automatically prefixed with that module's
  namespace such that given a module `MyApp.Users` and an event `:registered`, the
  resultant event will be compiled and ultimately emitted as `[:my_app, :users, :registered]`.

  Examples follow:

  ```elixir
  defmodule MyApp.Users do
    use Sibyl

    def sign_up(attrs) do
      Sibyl.emit(:registered) # Fails to compile as event is unknown.
    end
  end

  defmodule MyApp.Users do
    use Sibyl

    define_event :registered

    def sign_up(attrs) do
      Sibyl.emit(:registered) # Compiles properly and emits event
    end
  end
  ```

  ### Reflection

  Due to the fact that Sibyl is able to check whether or not events have been defined
  prior to use, Sibyl exposes a reflection API in the way of `Sibyl.Events.reflect/0`
  and `Sibyl.Events.reflect/1`.

  Please see documentation for `Sibyl.Events` if you're interested in more potential
  avenues for extending Sibyl or metaprogramming.

  ### Telemetry Handlers

  Building on top of Sibyl's reflection API, we are able to provide functions to
  automatically attach defined events to `:telemetry` handlers. You can do this via
  the helper functions in `Sibyl.Handlers`.

  Please see the documentation for `Sibyl.Handlers` for more information, but a brief
  usage example follows:

  ```elixir
  @impl Sibyl.Handler
  def handle_event(event, measurement, metadata, opts) do
    IO.inspect({event, measurement, metadata, opts})
  end

  :ok = Sibyl.Handlers.attach_all_events(__MODULE__)
  ```

  Additionally, Sibyl provides two example `:telemetry` handlers: a very basic
  Elixir `Logger` handler for demonstration purposes, as well as an `OpenTelemetry`
  handler which was what prompted the building of Sibyl in the first place.

  ### OpenTelemetry Integration

  OpenTelemetry is a widely understood specification for dealing with event emission
  and traces.

  One can use `OpenTelemetry` to be able to instrument your code base with events and
  traces quite easily. However; the Elixir community also very much utilises `:telemetry`
  as the standard telemetry/metric/span gathering library.

  It is possible, of course, to use `OpenTelemetry` as well as `:telemetry`, but it
  would be convinient to have one unified API which bridges both worlds.

  Very much inspired by the `OpentelemetryTelemetry` library, Sibyl provides a generic
  `:telemetry` handler which bridges *any* `:telemetry.span/3`-spec complaint events
  to `OpenTelemetry` traces.

  Simply attach the `Sibyl.Handlers.OpenTelemetry` handler and start tracing functions,
  any captured traces will be handled by your configured OLTP exporter of choice.

  For demonstration purposes, this project also contains a `docker-compose.yml` which
  sets up `Jaeger`: an easy to use distributed tracing UI to view spans which understands
  `OpenTelemetry`.

  ### Dynamic Tracing

  In order to aide debugging of running systems without needing to instrument your code
  with decorators or event emission, Sibyl also provides an *experimental* dynamic
  tracer which leverages the BEAM's built in tracing functionalities.

  Please make sure you understand what turning on the BEAM's tracing functionality
  can do to overload a production system however. This is not neccessarily advisable,
  but it _is_ possible.

  After enabling Sibyl's dynamic tracer and attaching a `:telemetry` handler, all future
  invokations of any given functions will be handled as though you had instrumented
  your codebase with `@decorate trace()`.

  Examples follow:

  ```elixir
  {:ok, _meta} = Sibyl.Dynamic.enable(Sibyl.Handlers.OpenTelemetry)
  {:ok, _meta} = Sibyl.Dynamic.trace(Enum, :map, 2)

  Enum.map([1, 2, 3], & &1) # Produces OpenTelemetry traces

  :ok = Sibyl.Dynamic.disable()
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
