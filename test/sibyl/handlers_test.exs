defmodule Sibyl.Handlers.HandlersTest do
  use ExUnit.Case

  use Sibyl
  alias Sibyl.Handlers

  import ExUnit.CaptureLog

  def handle_event(event, _measurement, _metadata, _) do
    send(self(), event)
  end

  setup do
    {:ok,
     executed?: fn event ->
       receive do
         ^event -> true
       after
         10 -> false
       end
     end}
  end

  test "attaching events to a handle without a name causes a warning" do
    assert capture_log(fn -> Handlers.attach_events([], __MODULE__) end) =~
             "it is recommended to pass one in."
  end

  test "attaching events to a handle with a name does not cause a warning" do
    assert capture_log(fn -> Handlers.attach_events([], __MODULE__, name: "test-logger") end) ==
             ""
  end

  test "attaching events to a handle with an invalid name raises" do
    assert_raise ArgumentError, fn ->
      Handlers.attach_events([], __MODULE__, name: :test_logger)
    end
  end

  describe "attach_all_events/1" do
    test "attaches all defined events to the given handler, executing said handler", ctx do
      Code.eval_string("""
      defmodule AttachAllEventsTest do
        use Sibyl
        define_event :some_event
      end
      """)

      capture_log(fn -> assert :ok = Handlers.attach_all_events(__MODULE__) end)

      assert :ok = Sibyl.emit([:attach_all_events_test, :some_event])
      assert ctx.executed?.([:attach_all_events_test, :some_event])
    end
  end

  describe "attach_module_events/1" do
    test "attaches all events defined by the given module to the given handler, executing said handler",
         ctx do
      Code.eval_string("""
      defmodule AttachModuleEventsTest do
        use Sibyl
        define_event :some_event
      end

      defmodule AttachModuleEventsTestTwo do
        use Sibyl
        define_event :some_event
      end
      """)

      capture_log(fn ->
        assert :ok = Handlers.attach_module_events(AttachModuleEventsTestTwo, __MODULE__)
      end)

      # These are valid events, but defined in the wrong module, so we won't
      # have attached them...
      assert :ok = Sibyl.emit([:attach_module_events_test, :some_event])
      refute ctx.executed?.([:attach_module_events_test, :some_event])

      # These are valid events that are defined in the given module, so we do
      # see these
      assert :ok = Sibyl.emit([:attach_module_events_test_two, :some_event])
      assert ctx.executed?.([:attach_module_events_test_two, :some_event])
    end
  end
end
