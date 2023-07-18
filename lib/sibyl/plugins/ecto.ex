defmodule Sibyl.Plugins.Ecto do
  @moduledoc """
  Sibyl plugin module for listening to telemetry events emitted by Ecto. See docs for `Sibyl.Plugin`
  for more information about plugins themselves.

  This plugin will extend Sibyl and enable any configured Sibyl handler to listen to various events emitted
  by `Ecto` including field resolution, query execution, and batching.

  Use via `Sibyl.Handlers.attach_all_events(plugins: [Sibyl.Plugins.Ecto])`.

  > #### Note {: .warning}
  >
  > This plugin is very much still a work in progress, and should not be used in production code!
  > This is due to the fact that Sibyl doesn't expose an easy way to skew the time of events.
  > As a result, any spans containing Ecto functions will be very skewed and offset. Ecto spans alone
  > work fine however, so this is a workable first PoC
  >
  > Additionally, as this plugin is still a work in progress, it is not guaranteed to be stable. There
  > are no unit tests provided to ensure this module does not change.
  """

  # coveralls-ignore-start

  @behaviour Sibyl.Plugin
  @behaviour Sibyl.Handler

  @plugin_prefix [:sibyl, :plugins]

  @proxy [[:repo, :query]]

  @impl Sibyl.Plugin
  def identity, do: Enum.join(@plugin_prefix, "-")

  @impl Sibyl.Plugin
  def init(opts \\ []) do
    stop()

    prefix = opts[:ecto_prefix]

    unless is_atom(opts[:ecto_prefix]) do
      raise ArgumentError,
        message: """
        Ecto Telemetry events require an atom `:prefix` to be provided, in order to be listened to.
        """
    end

    ecto_events = Enum.map(@proxy, &[prefix | &1])

    sibyl_events =
      ecto_events
      |> Enum.map(&(@plugin_prefix ++ &1))
      |> Enum.flat_map(fn event ->
        [event ++ [:start], event ++ [:end], event ++ [:exception]]
      end)

    :telemetry.attach_many(identity(), ecto_events, &__MODULE__.handle_event/4, {})
    sibyl_events
  end

  @impl Sibyl.Plugin
  def stop do
    :telemetry.detach(identity())
  end

  @impl Sibyl.Handler
  def handle_event(
        event,
        %{query_time: query_time, total_time: total_time} = measurement,
        metadata,
        _config
      ) do
    now = System.monotonic_time()

    start_metadata = %{
      node: node(),
      repo: metadata.repo,
      query: metadata.query,
      params: metadata.params,
      start_time: now - total_time
    }

    stop_metadata = %{
      result: elem(metadata.result, 1),
      stacktrace: metadata.stacktrace,
      stop_time: now,
      total_time: total_time,
      query_time: query_time
    }

    stop_event = (match?({:ok, _result}, metadata.result) && [:stop]) || [:exception]

    :ok =
      Sibyl.Events.emit(
        @plugin_prefix ++ event ++ [:start],
        Map.put(measurement, :monotonic_time, now - total_time),
        start_metadata
      )

    :ok =
      Sibyl.Events.emit(
        @plugin_prefix ++ event ++ stop_event,
        Map.put(measurement, :monotonic_time, now),
        stop_metadata
      )
  rescue
    _error -> :ok
  catch
    _error -> :ok
  end
end
