defmodule Sibyl.Handlers.OpenTelemetryTest do
  use ExUnit.Case

  alias Sibyl.Handlers.OpenTelemetry

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
