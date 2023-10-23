defmodule Sibyl.Events do
  @moduledoc """
  Module containing the core business logic of Sibyl.

  Includes utility functions to defining events, emitting events, and reflecting
  on events which are defined in any module loaded on the BEAM.
  """

  alias Sibyl.AST
  require Logger

  @type event() :: [atom()]
  @type sibyl_event() :: atom()

  @doc """
  Defines the given event.

  Events should only be used once they are defined. Unless this is done, `reflect/0`
  and `reflect/1` will fail to see said event and will eventually throw errors.

  When given a singular atom, it is assumed that the event you are trying to define
  is namespaced to said module as: `[:my_app, :my_module, :custom_event]`.

  When given a list of atoms, the event is simply registered as whatever you passed
  in; i.e. `[:some, :custom, :event]`.
  """
  @spec define_event(event(), module() | nil) :: AST.ast()
  defmacro define_event(event, module \\ nil)

  defmacro define_event(event, module) when is_atom(event) do
    module = module || __CALLER__.module
    event = build_event(module, nil, nil, event)

    quote bind_quoted: [module: module, event: event] do
      events = Enum.uniq([event | Module.get_attribute(module, :sibyl_telemetry_events)])
      Module.put_attribute(module, :sibyl_telemetry_events, events)
    end
  end

  defmacro define_event(event, module) do
    quote bind_quoted: [module: module, event: event] do
      events =
        Enum.uniq([event | Module.get_attribute(module || __MODULE__, :sibyl_telemetry_events)])

      Module.put_attribute(module || __MODULE__, :sibyl_telemetry_events, events)
    end
  end

  @doc """
  Given an atom denoting some abstract event (but not of type `event()`), builds an event
  name such that the given abstract event is formatted as per telemetry best practices.

  ## Examples (assuming this is being called in a module and function)

      iex> Sibyl.Events.build_event(:not_found)
      [:my_app, :"some_function/2", :not_found]

  """
  @spec build_event(event_fragment :: sibyl_event()) :: AST.ast()
  defmacro build_event(event) do
    module = __CALLER__.module
    {function, arity} = __CALLER__.function

    quote bind_quoted: [module: module, function: function, arity: arity, event: event] do
      Sibyl.Events.build_event(module, function, arity, event)
    end
  end

  @doc """
  Returns a list of all telemetry events which have been defined by `Sibyl.Events`
  """
  @spec reflect() :: [event()]
  def reflect do
    # Credo complains about the `Stream.concat(Task.async_stream(:code.all_loaded, ...))`
    # call below and wants to turn the inner function calls into a pipeline.
    #
    # Trying to do this makes Credo complain about the fact that its a pipeline with only
    # one function call in it....
    #
    # Thus, this is unresolvable. Ignoring.
    # credo:disable-for-lines:3
    :application.which_applications()
    |> Task.async_stream(&(&1 |> elem(0) |> :application.get_key(:modules) |> elem(1)))
    |> Stream.concat(Task.async_stream(:code.all_loaded(), &[elem(&1, 0)]))
    |> Stream.uniq()
    |> Stream.flat_map(fn {:ok, module} -> module end)
    |> Stream.filter(&match?({:module, _module}, :code.ensure_loaded(&1)))
    |> Task.async_stream(&reflect/1)
    |> Enum.flat_map(fn {:ok, events} -> events end)
  end

  @doc """
  Returns a list of all telemetry events which have been defined by `Sibyl.Events` for
  the given module.

  Note: some events may be implicitly defined via the top level `@decorate trace()`
  or `@decorate_all trace()` decorators.
  """
  @spec reflect(module()) :: [event()]
  def reflect(module) when is_atom(module) do
    try do
      # NOTE: Erlang modules are not supported,
      #       Fixes problematic errors when trying to run `:shell_default.__info__/1`
      #       on Elixir 1.15 or OTP 26
      match?("Elixir." <> _rest, Atom.to_string(module)) || throw(:skip)
      Module.get_attribute(module, :sibyl_telemetry_events)
    rescue
      ArgumentError ->
        :attributes
        |> module.__info__()
        |> Keyword.get(:sibyl_telemetry_events, [])
    end

    # coveralls-ignore-start
  rescue
    _e in [FunctionClauseError, UndefinedFunctionError] ->
      []
  catch
    :skip ->
      []
      # coveralls-ignore-stop
  end

  @doc """
  Returns true if event was defined.
  """
  @spec event?(event()) :: boolean()
  def event?(event) when is_list(event) do
    event in reflect()
  end

  @doc """
  Given a module that may, or may not, `use Sibyl` as well as an event, returns
  true if said module defines the given event.
  """
  @spec event?(module(), event()) :: boolean()
  def event?(module, event) when is_atom(module) and is_list(event) do
    event in reflect(module)
  end

  @doc """
  Builds a consistent telemetry event name following the conventions specified in
  [this post](https://keathley.io/blog/telemetry-conventions.html).

  Called like: `Sibyl.build_event(MyApp.Accounts, :register_user, 2, :email_sent)`,
  produces the following event: `[:my_app, :accounts, :"register_user/2", :email_sent]`
  """
  # IGNORE: we can't avoid not automatically generating atoms, but this should
  # only ever be run at compile time so should be safe.
  # credo:disable-for-lines:11
  @spec build_event(module(), function :: atom(), arity :: integer(), sibyl_event()) :: event()
  @spec build_event(module(), function :: nil, arity :: nil, sibyl_event()) :: event()
  def build_event(module, function, arity, event \\ nil)
      when is_atom(module) and (is_atom(function) or is_nil(function)) and
             (is_integer(arity) or is_nil(arity)) do
    module
    |> Module.split()
    |> Enum.map(&(&1 |> Macro.underscore() |> String.to_atom()))
    |> Enum.concat((function && [:"#{function}/#{arity}", event]) || [event])
    |> Enum.reject(&is_nil/1)
  end

  @doc "See `emit/4`"
  @spec emit(event(), measurements :: map(), metadata :: map()) :: :ok
  def emit(event, measurements \\ %{}, metadata \\ %{}) when is_list(event) do
    emit(__MODULE__, event, measurements, metadata)
  end

  @doc """
  Emits the given event.

  Note: this is a low level API which should not be called outside of Sibyl's own
  code, and largely exists to plumb together the system.

  Please prefer to use `Sibyl.emit/3` which includes compile time checks to make
  sure the events being emitted were registered.

  When given an event as an atom, tries to emit the event namespaced to the given
  module (see `define_event/2` for more information).

  When given a event as a list, simply emits that given list.
  """
  @spec emit(module(), event(), measurements :: map(), metadata :: map()) :: :ok
  @spec emit(module(), sibyl_event(), measurements :: map(), metadata :: map()) :: :ok
  def emit(_module, event, measurements, metadata) when is_list(event) do
    :telemetry.execute(event, measurements, metadata)
  end

  def emit(module, event, measurements, metadata) when is_atom(event) do
    module
    |> build_event(nil, nil, event)
    |> :telemetry.execute(measurements, metadata)
  end
end
