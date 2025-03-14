# Sibyl

[![hex.pm](https://img.shields.io/hexpm/v/sibyl.svg)](https://hex.pm/packages/sibyl)
[![hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/sibyl/)
[![hex.pm](https://img.shields.io/hexpm/dt/sibyl.svg)](https://hex.pm/packages/sibyl)
[![hex.pm](https://img.shields.io/hexpm/l/sibyl.svg)](https://hex.pm/packages/sibyl)

Easy, ergonomic telemetry & observability for Elixir applications.

## Why

Sibyl aims to solve three main problems:

1. It isn't always clear how best to emit telemetry events in your Elixir projects as `:telemetry` is rather low level, and a lot of examples focus on library code.
2. Telemetry & observability is either too high level, or requires a lot of mainly instrumentation which can be noisy and be error-prone when done manually.
3. Emitting events/telemetry and consuming them are seperated concerns. You're on your own for deciding how to consume the events you do emit in your code.

The above is actually great for building libraries where you want to emit events and allow external users to consume said events, and do so in an unopinionated
way. However, applications tend to emit events explicitly so that they can be consumed, and tend to want to do so in an opinionated or constrained way.

Sibyl tries to solve the above by being a light wrapper around `:telemetry` and embracing OpenTelemetry.

## Installation

Add `:sibyl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sibyl, "~> 0.1.0"}
  ]
end
```

Currently, Sibyl requires Elixir 1.15 or higher. We aim to support Sibyl for the three most recent Elixir major releases at any given time.

## Usage

Sibyl is an opinionated library that aims to get you tracing your code and emitting metrics with minimal instrumentation as quickly as possible!

Before actually emitting any metrics/events in your code, you need to configure Sibyl to automatically start up by adding the following to your
project's `Application` module:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    ...
  after
    :ok = Sibyl.Handlers.attach_all_events(Sibyl.Handlers.OpenTelemetry)
  end
end
```

### Tracing Functions

You can start tracing functions, capturing their runtime, return values, exceptions, and more by using the `trace/0` macro with the `@decorate` directive
which is provided to any module that has `use Sibyl` in it.

Traced functions automatically emit `:telemetry` events when they initially get called, when they end, and when they throw an exception. Sibyl will
capture the time elapsed, arguments provided, return value, and any events (and their measurements, metadata) emitted during the function.

```elixir
defmodule MyApp.Users do
  alias MyApp.User
  alias MyApp.Repo

  use Sibyl

  @decorate trace()
  def register(attrs) do
    attrs
    |> User.changeset()
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        {:ok, user}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Tracing Modules

Typically, we recommend that functions be traced with purpose to minimize noise, however, Sibyl is able to automatically trace every function defined in a
module that using the `trace/0` macro with the `@decorate_all` directive instead of `@decorate`.

```elixir
defmodule MyApp.Users do
  use Sibyl

  @decorate_all trace()

  def register(attrs) do
    attrs
    |> User.changeset()
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        {:ok, user}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Emitting Events

Additionally, aside from tracing the runtime and state of your functions, Sibyl also makes it easy to emit arbitrary events
and metrics in your application.

Unlike using the standard `:telemetry` library directly, Sibyl will ensure that any event being emitted was previously defined
by Sibyl at compile time. This guarantees that events that are emitted exist, and makes your events durable across refactors and
renaming.

You can define events with the `define_event/1` macro which is automatically imported whenever you `use Sibyl`, and you can
emit them via the `emit/1` macro:

```elixir
defmodule MyApp.Users do
  use Sibyl

  define_event(:registration)
  define_event(:registration_failed)

  def create_user(attrs) do
    attrs
    |> User.changeset()
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        emit(:registration)
        {:ok, user}

      {:error, changeset} ->
        emit(:registration_failed)
        {:error, changeset}
    end
  end
end
```

Alternatively, events can be defined in other modules and emitted by referencing the definer such as:

```elixir
defmodule MyApp.Events do
  use Sibyl

  define_event(:function_executed)
  define_event(:api_key_requests)
  define_event(:user_requests)
end

defmodule MyApp.Users do
  use Sibyl
  alias MyApp.Events

  def create_user(attrs) do
    emit(Events, :function_executed)
    if is_api_user(self())?, do: emit(Events, :api_key_requests),
                             else: emit(Events, :user_requests)

    attrs
    |> User.changeset()
    |> Repo.insert()
  end
end
```

### Plugins

Because Sibyl builds on top of the de-facto telemetry library for the BEAM, it's able to provide an easy way to extend
the events Sibyl is able to handle via first class plugins.

You can configure plugins on a handler by handler basis via the following configuration:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    ...
  after
    :ok = Sibyl.Handlers.attach_all_events(Sibyl.Handlers.OpenTelemetry, plugins: [
      Sibyl.Plugins.Absinthe,
      Sibyl.Plugins.Ecto,
      ...
    ])
  end
end
```

See the [documentation](https://hexdocs.pm/sibyl/) for more information.

### Runtime Tracing

Sibyl is additionally able to trace and handle `:telemetry` events entirely at runtime, with no orchestration needed
at all!

This is done by leveraging the BEAM's built in `trace/3` BIFs, mapping internal BEAM events to `:telemetry` alike event
emissions.

Using `Sibyl.Dynamic` looks like the following:

```elixir
iex> Sibyl.Dynamic.enable(Sibyl.Handlers.OpenTelemetry)
iex> Sibyl.Dynamic.trace(MyApp.Users, :create_user, 1)
iex> MyApp.Users.create_user(%{email: "test"}) # Emits Sibyl-compatible `:telemetry` events
{:ok, %MyApp.User{}}
```

## Additional Features

See the [documentation](https://hexdocs.pm/sibyl/) for more exhaustive information about Sibyl's features, but other features
not covered by the above includes:

- Open and extendable `Sibyl.Handler` behaviour for defining alternative handlers
- Speedscope and Chrome compatible flamegraph handler via `Sibyl.Handlers.FlameGraph`
- More soon!

## Contributing

We enforce 100% code coverage and a strict linting setup for Sibyl.

Please ensure that commits pass CI. You should be able to run both `mix test` and `mix lint` locally.

See the `mix.exs` to see the breakdown of what these commands do.

Additionally, we develop Sibyl using tools to manage our Elixir versions such as [`asdf`](https://asdf-vm.com) or [`nix`](https://nixos.org).
Please see [`.tool-versions`](./tool-versions) or [`shell.nix`](./shell.nix) accordingly.

## License

See [LICENSE.md](./LICENSE)
