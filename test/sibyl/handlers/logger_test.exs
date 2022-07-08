defmodule Sibyl.Handlers.LoggerTest do
  use ExUnit.Case

  alias Sibyl.Handlers.Logger
  import ExUnit.CaptureLog

  describe "handle_event/4" do
    test "logs the given telemetry event" do
      event = [:some, :random, :event]
      measurement = "some measurement"
      metadata = "some metadata"

      assert output =
               capture_log(fn ->
                 Logger.handle_event(event, measurement, metadata,
                   name: "some name",
                   level: :warning
                 )
               end)

      assert output =~ "Captured event `[:some, :random, :event]` in handler name `some name`"
      assert output =~ "some measurement"
      assert output =~ "some metadata"
    end
  end
end
