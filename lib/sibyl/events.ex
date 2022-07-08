defmodule Sibyl.Events do
  @moduledoc """
  Module containing the core business logic of Sibyl.

  Includes utility functions to defining events, emitting events, and reflecting
  on events which are defined in any module loaded on the BEAM.
  """

  @type event() :: [atom()]
  @type ast() :: term()

  @doc """
  Defines the given event.

  Events should only be used once they are defined. Unless this is done, `reflect/0`
  and `reflect/1` will fail to see said event and will eventually throw errors.

  When given a singular atom, it is assumed that the event you are trying to define
  is namespaced to said module as: `[:my_app, :my_module, :custom_event]`.

  When given a list of atoms, the event is simply registered as whatever you passed
  in; i.e. `[:some, :custom, :event]`.
  """
  @spec define_event(event(), module() | nil) :: ast()
  defmacro define_event(event, module \\ nil)

  defmacro define_event(event, module) when is_atom(event) do
    module = module || __CALLER__.module
    event = build_event(module, nil, nil, event)

    quote do
      event = unquote(event)
      module = unquote(module)
      events = Enum.uniq([event | Module.get_attribute(module, :sibyl_telemetry_events)])
      Module.put_attribute(module, :sibyl_telemetry_events, events)
    end
  end

  defmacro define_event(event, module) do
    quote do
      event = unquote(event)
      module = unquote(module) || __MODULE__
      events = Enum.uniq([event | Module.get_attribute(module, :sibyl_telemetry_events)])
      Module.put_attribute(module, :sibyl_telemetry_events, events)
    end
  end

  @doc """
  Given an atom denoting some abstract event (but not of type `event()`), builds an event
  name such that the given abstract event is formatted as per telemetry best practices.

  ## Examples (assuming this is being called in a module and function)

      iex> Sibyl.Events.build_event(:not_found)
      [:my_app, :"some_function/2", :not_found]

  """
  @spec build_event(event_fragment :: atom()) :: ast()
  defmacro build_event(event) do
    module = __CALLER__.module
    {function, arity} = __CALLER__.function

    quote do
      Sibyl.Events.build_event(unquote(module), unquote(function), unquote(arity), unquote(event))
    end
  end

  # TODO: hopefully we can discover what modules are dependencies and exclude
  # them from the static module invokation below?
  @doc """
  Returns a list of all telemetry events which have been defined by `Sibyl.Events`
  """
  @spec reflect() :: [event()]
  def reflect do
    static_modules =
      Enum.flat_map(:application.which_applications(), fn {application, _description, _version} ->
        application
        |> :application.get_key(:modules)
        |> elem(1)
      end)

    dynamic_modules =
      :code.all_loaded() |> Enum.map(&elem(&1, 0)) |> Enum.reject(&(&1 in static_modules))

    static_modules
    |> Enum.concat(dynamic_modules)
    |> Enum.filter(&match?({:module, _module}, :code.ensure_loaded(&1)))
    |> Enum.flat_map(&reflect/1)
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
      Module.get_attribute(module, :sibyl_telemetry_events)
    rescue
      ArgumentError ->
        :attributes
        |> module.__info__()
        |> Keyword.get(:sibyl_telemetry_events, [])
    end
  rescue
    _e in [FunctionClauseError, UndefinedFunctionError] ->
      []
  end

  @doc """
  Returns true if event was defined.
  """
  @spec is_event(event()) :: boolean()
  def is_event(event) when is_list(event) do
    event in reflect()
  end

  @doc """
  Given a module that may, or may not, `use Sibyl` as well as an event, returns
  true if said module defines the given event.
  """
  @spec is_event(module(), event()) :: boolean()
  def is_event(module, event) when is_atom(module) and is_list(event) do
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
  @spec build_event(module(), function :: atom(), arity :: integer(), event :: atom()) :: event()
  @spec build_event(module(), function :: nil, arity :: nil, event :: atom()) :: event()
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
  @spec emit(module(), atom(), measurements :: map(), metadata :: map()) :: :ok
  def emit(_module, event, measurements, metadata) when is_list(event) do
    :telemetry.execute(event, measurements, metadata)
  end

  def emit(module, event, measurements, metadata) when is_atom(event) do
    module
    |> build_event(nil, nil, event)
    |> :telemetry.execute(measurements, metadata)
  end
end
