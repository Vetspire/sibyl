defmodule Sibyl.Handler do
  @moduledoc "Behaviour for `:telemetry` handlers"

  alias Sibyl.Events

  @callback handle_event(
              event :: Events.event(),
              measurement :: term(),
              metadata :: term(),
              config :: term()
            ) :: any()
end
