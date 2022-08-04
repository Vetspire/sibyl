defmodule Sibyl.Handlers.OpenTelemetryTest do
  use ExUnit.Case

  alias Sibyl.Handlers.OpenTelemetry

  describe "undefined_trace_context/0" do
    test "returns a constant" do
      assert OpenTelemetry.undefined_trace_context() == "g2QACXVuZGVmaW5lZA=="
    end
  end

  describe "build_distributed_trace_context/0" do
    test "returns a base64 encoded string which can be decoded into its original form" do
      assert encoded_ctx = OpenTelemetry.build_distributed_trace_context()

      assert decoded_ctx =
               encoded_ctx
               |> Base.decode64!()
               |> :erlang.binary_to_term()

      assert :ok = OpenTelemetry.attach_distributed_trace_context(encoded_ctx)

      assert {{OpenTelemetry, :distributed_trace_context}, decoded_ctx} ==
               Enum.find(
                 Process.get(),
                 &(is_tuple(&1) && is_tuple(elem(&1, 0)) &&
                     elem(elem(&1, 0), 1) == :distributed_trace_context)
               )
    end
  end

  describe "handle_event/4" do
    setup do
      {:ok,
       callback: fn state -> send(self(), {:executed, state}) end,
       executed?: fn state ->
         receive do
           {:executed, ^state} -> true
         after
           10 -> false
         end
       end}
    end

    test "given no callback, still runs" do
      event = [:elixir, :enum, :"map/2", :start]
      measurement = %{}
      metadata = %{}

      assert OpenTelemetry.handle_event(event, measurement, metadata, [])
    end

    test "given a start event, runs the bridge code to construct a start span OT event", ctx do
      event = [:elixir, :enum, :"map/2", :start]
      measurement = %{}
      metadata = %{args: [1, 2]}

      assert OpenTelemetry.handle_event(event, measurement, metadata, callback: ctx.callback)
      assert ctx.executed?.(:start)
    end

    test "given a stop event, runs the bridge code to construct a stop span OT event", ctx do
      event = [:elixir, :enum, :"map/2", :stop]
      measurement = %{}
      metadata = %{}

      assert OpenTelemetry.handle_event(event, measurement, metadata, callback: ctx.callback)
      assert ctx.executed?.(:stop)
    end

    test "given an exception event, runs the bridge code to construct an error span OT event",
         ctx do
      event = [:elixir, :enum, :"map/2", :exception]
      measurement = %{}
      metadata = %{exception: %ArgumentError{}}

      assert OpenTelemetry.handle_event(event, measurement, metadata, callback: ctx.callback)
      assert ctx.executed?.(:exception)
    end

    test "given a throw event, runs the bridge code to construct an error span OT event",
         ctx do
      event = [:elixir, :enum, :"map/2", :exception]
      measurement = %{}
      metadata = %{}

      assert OpenTelemetry.handle_event(event, measurement, metadata, callback: ctx.callback)
      assert ctx.executed?.(:exception)
    end

    test "given any other event, runs the bridge code to emit an OT custom event", ctx do
      event = [:elixir, :enum, :"map/2", :whatever]
      measurement = %{}
      metadata = %{}

      assert OpenTelemetry.handle_event(event, measurement, metadata, callback: ctx.callback)
      assert ctx.executed?.(:custom)
    end
  end
end
