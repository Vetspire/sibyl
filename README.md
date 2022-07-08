# Sibyl

Sibyl is a library which augments the BEAM's default tracing capabilities by hooking
into `:telemetry`, `:dbg` (the BEAM's built in tracing and debugging functionality),
and `OpenTelemetry`.

See the [official documentation for Sibly](https://hexdocs.pm/sibyl/api-reference.html).

## Installation

This package can be installed by adding `sibyl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sibyl, "~> 0.1.0"}
  ]
end
```

### Basic Usage

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

## Contributing

We enforce 100% code coverage and quite a strict linting setup for Sibyl.

Please ensure that commits pass CI. You should be able to run both `mix test` and
`mix lint` locally.

See the `mix.exs` to see the breakdown of what these commands do.
