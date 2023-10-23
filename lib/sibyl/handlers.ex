defmodule Sibyl.Handlers do
  @moduledoc """
  Groups functions to make it easy to attach telemetry events to handlers
  """

  alias Sibyl.Events
  require Logger

  @type handler() :: module()

  @doc """
  Reflects upon the state of the current application's modules and all other dynamically
  loaded module and attaches any events defined in those modules to the given handler.

  Any options are forwarded to the given handler also.
  Takes an optional, but recommended `:name => String.t()` option too.
  """
  @spec attach_all_events(handler(), Keyword.t()) :: :ok
  def attach_all_events(handler, opts \\ []) do
    attach_events(Sibyl.Events.reflect(), handler, opts)
  end

  @doc """
  Reflects upon the given module and attaches any events defined in those modules to
  the given handler.

  Any options are forwarded to the given handler also.
  Takes an optional, but recommended `:name => String.t()` option too.
  """
  @spec attach_module_events(module(), handler(), Keyword.t()) :: :ok
  def attach_module_events(module, handler, opts \\ []) when is_atom(module) do
    module
    |> Sibyl.Events.reflect()
    |> attach_events(handler, opts)
  end

  @doc """
  Attaches the given events the given handler.

  Any options are forwarded to the given handler also.
  Takes an optional, but recommended `:name => String.t()` option too.
  """
  @spec attach_events([Events.event()], handler(), Keyword.t()) :: :ok
  def attach_events(events, handler, opts \\ [])
      when is_list(events) and is_atom(handler) and is_list(opts) do
    plugin_events =
      opts
      |> Keyword.get(:plugins, [])
      |> Enum.flat_map(& &1.init(opts))

    opts
    |> ensure_name()
    |> :telemetry.attach_many(events ++ plugin_events, &handler.handle_event/4, opts)
  end

  defp ensure_name(opts) do
    case Keyword.get(opts, :name) do
      name when is_binary(name) ->
        name

      nil ->
        Logger.warning("Sibyl can attach without a name but it is recommended to pass one in.")
        inspect(make_ref())

      otherwise ->
        error_payload = inspect(otherwise)

        raise ArgumentError,
          message: "opts[:name] should be of type `String.t()`, got: `#{error_payload}`"
    end
  end
end
