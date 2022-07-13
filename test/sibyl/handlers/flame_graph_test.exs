defmodule Sibyl.Handlers.FlameGraphTest do
  use ExUnit.Case, async: false

  alias Sibyl.Handlers.FlameGraph
  alias Sibyl.Handlers

  describe "start/0" do
    test "returns `:ok` and initialises state on first run" do
      refute FlameGraph.started?()
      assert :ok = FlameGraph.start()
      assert FlameGraph.started?()
    end

    test "raises exception if already started" do
      assert :ok = FlameGraph.start()
      assert_raise ArgumentError, fn -> FlameGraph.start() end
    end
  end

  describe "stop/1" do
    setup do
      filepath =
        :sibyl
        |> :code.priv_dir()
        |> tap(&File.mkdir_p/1)
        |> Path.join("test.json")

      on_exit(fn -> File.rm(filepath) end)

      {:ok, filepath: filepath}
    end

    test "raises exception if not already started", ctx do
      assert_raise ArgumentError, fn -> FlameGraph.stop(ctx.filepath) end
    end

    test "returns `:ok` and writes empty traces to file if no traces were captured", ctx do
      assert :ok = FlameGraph.start()
      assert :ok = FlameGraph.stop(ctx.filepath)

      assert {:ok, data} = File.read(ctx.filepath)

      assert %{
               "meta_cpu_count" => _cpu_count,
               "meta_user" => "Elixir.Sibyl.Handlers.FlameGraph",
               "traceEvents" => []
             } = Jason.decode!(data)
    end

    test "returns `:ok` and captures telemetry start/stop events in file", ctx do
      Code.eval_string("""
        defmodule FlameGraph1 do
          use Sibyl
          @decorate_all trace()

          def hello do
            world()
            world()
            world()
            something_else()
            :ok
          end

          def world, do: :ok
          def something_else, do: world() && :ok
        end
      """)

      assert :ok = FlameGraph.start()
      assert :ok = Handlers.attach_module_events(FlameGraph1, FlameGraph, name: "flamegraph-test")
      assert :ok = apply(FlameGraph1, :hello, [])
      assert :ok = FlameGraph.stop(ctx.filepath)

      assert {:ok, data} = File.read(ctx.filepath)

      assert %{
               "meta_cpu_count" => _cpu_count,
               "meta_user" => "Elixir.Sibyl.Handlers.FlameGraph",
               "traceEvents" => trace_events
             } = Jason.decode!(data)

      # Sort by timestamp and compare expected function execution order
      assert [
               %{"name" => "flame_graph1.hello/0"},
               %{"name" => "flame_graph1.world/0"},
               %{"name" => "flame_graph1.world/0"},
               %{"name" => "flame_graph1.world/0"},
               %{"name" => "flame_graph1.something_else/0"},
               %{"name" => "flame_graph1.world/0"}
             ] = Enum.sort_by(trace_events, & &1["ts"])
    end
  end
end
