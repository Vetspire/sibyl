defmodule Sibyl.Handlers.FlameGraph do
  @moduledoc """
  An example Telemetry handler converting `:telemetry` events into Chrome-compatible
  flamegraphs.

  Exposes two additional functions when compared to traditional `Sibyl.Handler`s:

  1) `start/0` which instructs #{__MODULE__} to start persisting metadata in order
     to build the resultant flamegraph.

  2) `stop/1` which instructs #{__MODULE__} to flush any captured metadata into a
     JSON file for further use.

  If you're using a Chrome-derived browser, you'll be able to open and introspect
  generated flamegraphs via the [Chrome Tracing](chrome://tracing) builtin. Otherwise,
  you can use open source tools which understand Chrome Tracing's format to render
  graphs.

  Examples of open source apps that can render Chrome Traces include
  [Speedscope](https://www.speedscope.app/) and [Perfetto](https://perfetto.dev/).

  Note that this utility has only been tested and confirmed working with telemetry
  explicitly passed in via `Sibyl` and may not work when listening to arbitrary
  `:telemetry` events passed in from other OTP applications.

  Notes on the file format used by Google's tracer, Speedscope, and other related tools
  [can be found here](https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU/edit#).
  """

  @behaviour Sibyl.Handler

  alias __MODULE__
  require Logger

  @doc """
  Instructs #{__MODULE__} to start capturing and persisting `:telemetry` metadata.
  """
  @spec start :: :ok
  def start do
    if started?() do
      raise ArgumentError,
        message: "#{FlameGraph} is already started. Only one instance can run at any given time."
    end

    init_ets()
    :ok
  end

  defp init_ets do
    unless started?() do
      :ets.new(FlameGraph, [:duplicate_bag, :public, :named_table, write_concurrency: true])
    end

    :ok
  end

  @doc """
  Returns `true` if #{FlameGraph} has been started prior to invokation.
  """
  @spec started?() :: boolean()
  def started?, do: :ets.whereis(FlameGraph) != :undefined

  @doc """
  Instructs #{__MODULE__} to output any captured `:telemetry` metadata into the JSON
  file of your choice.
  """
  @spec stop(output_filepath :: Path.t()) :: :ok
  def stop(output_filepath) do
    unless started?() do
      raise ArgumentError,
        message: """
        #{FlameGraph} was not started. Please ensure you start #{FlameGraph} before stopping.
        """
    end

    metadata_export = :ets.tab2list(FlameGraph)
    true = :ets.delete(FlameGraph)

    pids =
      metadata_export
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()
      |> Map.new(fn pid ->
        {parsed, _rest} =
          pid
          |> inspect()
          |> String.trim_leading("#PID<")
          |> String.trim_trailing(">")
          |> String.replace(".", "")
          |> Integer.parse()

        {pid, parsed}
      end)

    trace_events = Enum.map(metadata_export, fn {pid, data} -> Map.put(data, :pid, pids[pid]) end)

    File.write!(
      output_filepath,
      Jason.encode!(%{
        "traceEvents" => trace_events,
        "meta_user" => "#{FlameGraph}",
        "meta_cpu_count" => "#{:erlang.system_info(:logical_processors_available)}"
      })
    )
  end

  @impl Sibyl.Handler
  def handle_event(event, measurement, metadata, _config) do
    if started?() do
      event
      |> List.pop_at(length(event) - 1)
      |> do_handle_event(measurement, metadata)
    else
      :ok
    end
  end

  # TODO: for `exception` events, we should persist custom metadata to call out
  # the fact that we've thrown an exception.
  defp do_handle_event({event, mfa}, measurement, metadata) when event in [:stop, :exception] do
    pid = self()
    %{monotonic_time: monotonic_time, duration: duration} = measurement
    %{args: args} = metadata

    :ets.insert(
      FlameGraph,
      {pid,
       %{
         tid: 1,
         ts: monotonic_time - duration,
         dur: duration,
         ph: "X",
         name: Enum.join(mfa, "."),
         args: args
       }}
    )

    :ok
  end

  defp do_handle_event(_event, _measurement, _metadata) do
    :ok
  end
end
