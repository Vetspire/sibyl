defmodule Sibyl.DynamicTest do
  use ExUnit.Case, async: false
  alias Sibyl.Dynamic

  setup do
    on_exit(fn -> Dynamic.disable() end)
  end

  describe "enable/1" do
    test "registers the Logger handler into global state when not provided one explicitly" do
      node = node()
      assert {:ok, [{:matched, ^node, _misc}]} = Dynamic.enable()
      assert [handler: Sibyl.Handlers.Logger] = :ets.lookup(Dynamic, :handler)
    end

    test "registers the given handler into global state" do
      node = node()
      assert {:ok, [{:matched, ^node, _misc}]} = Dynamic.enable(Sibyl.Handlers.OpenTelemetry)
      assert [handler: Sibyl.Handlers.OpenTelemetry] = :ets.lookup(Dynamic, :handler)
    end
  end

  describe "trace/3" do
    def handle_event(event, measurement, _metadata, _config) do
      [test_proc: test_proc] = :ets.lookup(Dynamic, :test_proc)
      send(test_proc, {event, measurement})
    end

    test "listens for all invokations of given MFA and fires handler's `handle_event/4` callback" do
      emitted = fn event ->
        receive do
          {^event, measurement} -> measurement
        after
          100 -> false
        end
      end

      node = node()
      assert {:ok, [{:matched, ^node, _misc}]} = Dynamic.enable(__MODULE__)
      assert {:ok, [{:matched, ^node, _misc}, saved: 1]} = Dynamic.trace(String, :starts_with?, 2)

      # HACK: let the `handle_event/4` callback defined above know about us, because that's actually going
      # to be run in the dbg process -- not our own.
      :ets.insert(Dynamic, {:test_proc, self()})

      _ = String.starts_with?("Hello, world!", "Hello")
      assert %{args: ["Hello, world!", "Hello"]} = emitted.([:string, :"starts_with?/2", :start])
      assert %{return_value: true} = emitted.([:string, :"starts_with?/2", :stop])

      _ = String.starts_with?("Hello, world!", "Good Bye")

      assert %{args: ["Hello, world!", "Good Bye"]} =
               emitted.([:string, :"starts_with?/2", :start])

      assert %{return_value: false} = emitted.([:string, :"starts_with?/2", :stop])
    end
  end
end
