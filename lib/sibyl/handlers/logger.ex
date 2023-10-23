defmodule Sibyl.Handlers.Logger do
  @moduledoc """
  An example Telemetry handler for logging given events to the current application's
  configured logger.

  Please note that this very much *is an example*. There is little reason to do this
  in production code.
  """

  @behaviour Sibyl.Handler

  require Logger

  @impl Sibyl.Handler
  def handle_event(event, measurement, metadata, config) do
    name = Keyword.get(config, :name)

    event_string = inspect(event)
    measurement_string = inspect(measurement)
    metadata_string = inspect(metadata)

    config
    |> Keyword.get(:level, :info)
    |> Logger.log(fn ->
      """
      Captured event `#{event_string}` in handler name `#{name}` which reports the following:
        - Measurements:
        #{measurement_string}

        - Metadata:
        #{metadata_string}
      """
    end)
  end
end
