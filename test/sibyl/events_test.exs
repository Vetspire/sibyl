defmodule Sibyl.Handlers.EventsTest do
  use ExUnit.Case
  require Sibyl.Events, as: Events

  describe "reflect/1" do
    test "returns empty list when module does not define any events" do
      assert [] = Events.reflect(Enum)
    end

    test "returns list of all events which are manually defined in given module" do
      Code.eval_string("""
        defmodule MyApp.ReflectTestOne do
          use Sibyl
          define_event :test
          define_event :another_test
        end
      """)

      assert events = Events.reflect(MyApp.ReflectTestOne)

      assert [:my_app, :reflect_test_one, :test] in events
      assert [:my_app, :reflect_test_one, :another_test] in events
      assert length(events) == 2
    end

    test "returns list of all events which are automatically defined by `@decorate_all trace()`" do
      Code.eval_string("""
        defmodule MyApp.ReflectTestTwo do
          use Sibyl

          @decorate_all trace()
          def hello, do: :world
          def world, do: :hello
        end
      """)

      assert events = Events.reflect(MyApp.ReflectTestTwo)

      assert [:my_app, :reflect_test_two, :"world/0", :exception] in events
      assert [:my_app, :reflect_test_two, :"world/0", :stop] in events
      assert [:my_app, :reflect_test_two, :"world/0", :start] in events
      assert [:my_app, :reflect_test_two, :"hello/0", :exception] in events
      assert [:my_app, :reflect_test_two, :"hello/0", :stop] in events
      assert [:my_app, :reflect_test_two, :"hello/0", :start] in events
      assert length(events) == 6
    end

    test "returns list of all events which are automatically defined by `@decorate trace()`" do
      Code.eval_string("""
        defmodule MyApp.ReflectTestFive do
          use Sibyl

          def hello, do: :world

          @decorate trace()
          def world, do: :hello
        end
      """)

      assert events = Events.reflect(MyApp.ReflectTestFive)

      # This function *was* decorated, so these events are reflectable.
      assert [:my_app, :reflect_test_five, :"world/0", :exception] in events
      assert [:my_app, :reflect_test_five, :"world/0", :stop] in events
      assert [:my_app, :reflect_test_five, :"world/0", :start] in events

      # This function wasn't decorated, so these events shouldn't be reflectable.
      refute [:my_app, :reflect_test_five, :"hello/0", :exception] in events
      refute [:my_app, :reflect_test_five, :"hello/0", :stop] in events
      refute [:my_app, :reflect_test_five, :"hello/0", :start] in events

      assert length(events) == 3
    end
  end

  describe "reflect/0" do
    test "returns list of all events which are manually defined" do
      Code.eval_string("""
        defmodule MyApp.ReflectTestThree do
          use Sibyl
          define_event :test
          define_event :another_test
        end
      """)

      assert events = Events.reflect()

      assert [:my_app, :reflect_test_three, :test] in events
      assert [:my_app, :reflect_test_three, :another_test] in events
    end

    test "returns list of all events which are automatically" do
      Code.eval_string("""
        defmodule MyApp.ReflectTestFour do
          use Sibyl

          @decorate_all trace()
          def hello, do: :world
          def world, do: :hello
        end
      """)

      assert events = Events.reflect()

      assert [:my_app, :reflect_test_four, :"world/0", :exception] in events
      assert [:my_app, :reflect_test_four, :"world/0", :stop] in events
      assert [:my_app, :reflect_test_four, :"world/0", :start] in events
      assert [:my_app, :reflect_test_four, :"hello/0", :exception] in events
      assert [:my_app, :reflect_test_four, :"hello/0", :stop] in events
      assert [:my_app, :reflect_test_four, :"hello/0", :start] in events
    end
  end

  describe "event?/1" do
    test "returns false when event is not a valid event" do
      refute Events.event?([:my_app, :something_random, :test])
    end

    test "returns list of all events which are manually defined in given module" do
      Code.eval_string("""
        defmodule MyApp.ReflectTestFive do
          use Sibyl
          define_event [:my_app, :something_random, :diff_test]
        end
      """)

      assert Events.event?([:my_app, :something_random, :diff_test])
    end
  end

  describe "event?/2" do
    test "returns false when event is not a valid event" do
      refute Events.event?(Enum, [:my_app, :something_random, :test])
    end

    test "returns true if event is a valid event and also defined in given module" do
      Code.eval_string("""
        defmodule MyApp.ReflectTestSix do
          use Sibyl
          define_event [:my_app, :something_random, :sixth_test]
        end
      """)

      assert Events.event?(MyApp.ReflectTestSix, [:my_app, :something_random, :sixth_test])
      refute Events.event?(Enum, [:my_app, :something_random, :sixth_test])
    end
  end

  describe "build_event/1" do
    test "namespaces event under module and function" do
      assert [
               :sibyl,
               :handlers,
               :events_test,
               :"test build_event/1 namespaces event under module and function/1",
               :test
             ] = Events.build_event(:test)
    end
  end

  describe "emit/3" do
    test "returns `:ok` regardless of the exact event passed in" do
      assert :ok = Events.emit([:some_event], %{}, %{})
    end
  end

  describe "emit/4" do
    test "returns `:ok` regardless of the exact event or module passed in" do
      assert :ok = Events.emit(Enum, [:some_event], %{}, %{})
      assert :ok = Events.emit(Enum, :some_atom, %{}, %{})
    end
  end
end
