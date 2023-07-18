defmodule Sibyl.Plugins.Absinthe do
  @moduledoc """
  Sibyl plugin module for listening to telemetry events emitted by Absinthe. See docs for `Sibyl.Plugin`
  for more information about plugins themselves.

  This plugin will extend Sibyl and enable any configured Sibyl handler to listen to various events emitted
  by `Absinthe` including field resolution, query execution, and batching.

  Use via `Sibyl.Handlers.attach_all_events(plugins: [Sibyl.Plugins.Absinthe])`.

  > #### Note {: .warning}
  >
  > This plugin is very much still a work in progress, and should not be used in production code!
  >
  > Additionally, as this plugin is still a work in progress, it is not guaranteed to be stable. There
  > are no unit tests provided to ensure this module does not change.
  """

  # coveralls-ignore-start

  @behaviour Sibyl.Handler
  use Sibyl.Plugin

  @proxy %{
    [:absinthe, :execute, :operation, :start] => [:sibyl, :plugins, :absinthe, :operation, :start],
    [:absinthe, :execute, :operation, :stop] => [:sibyl, :plugins, :absinthe, :operation, :stop],
    [:absinthe, :resolve, :field, :start] => [
      :sibyl,
      :plugins,
      :absinthe,
      :resolve,
      :field,
      :start
    ],
    [:absinthe, :resolve, :field, :stop] => [:sibyl, :plugins, :absinthe, :resolve, :field, :stop],
    [:absinthe, :middleware, :batch, :start] => [
      :sibyl,
      :plugins,
      :absinthe,
      :middleware,
      :batch,
      :start
    ],
    [:absinthe, :middleware, :batch, :stop] => [
      :sibyl,
      :plugins,
      :absinthe,
      :middleware,
      :batch,
      :stop
    ]
  }

  @impl Sibyl.Plugin
  def init(_opts \\ []) do
    stop()
    :telemetry.attach_many(identity(), Map.keys(@proxy), &__MODULE__.handle_event/4, {})
    Map.values(@proxy)
  end

  @impl Sibyl.Handler
  def handle_event(event, measurement, metadata, _config) do
    base_metadata = %{node: node()}

    Sibyl.Events.emit(
      @proxy[event],
      Map.put(measurement, :monotonic_time, System.monotonic_time()),
      Map.merge(base_metadata, parse_event(event, metadata))
    )
  rescue
    _error -> :ok
  catch
    _error -> :ok
  end

  defp parse_event([:absinthe, :execute | _rest], metadata) do
    document = Keyword.get(metadata.options, :document)

    %{
      document: document,
      args: Keyword.get(metadata.options, :variables),
      context: Keyword.get(metadata.options, :context),
      event_name: "query:" <> (Keyword.get(metadata.options, :operation_name) || "anonymous")
    }
  end

  defp parse_event([:absinthe, :resolve | _rest], metadata) do
    %{
      schema: metadata.resolution.schema,
      args: metadata.resolution.arguments,
      value: inspect(metadata.resolution.value),
      event_name: "field:" <> (metadata.resolution.path |> List.first() |> Map.get(:name))
    }
  end

  defp parse_event([:absinthe, :middleware, :batch | _rest], metadata) do
    arity = 2
    [module, function | _rest] = Tuple.to_list(metadata.batch_fun)
    mfa = "#{inspect(module)}.#{function}/#{arity}"

    %{event_name: "batch:" <> mfa, mfa: mfa, args: metadata.batch_data}
  end
end
