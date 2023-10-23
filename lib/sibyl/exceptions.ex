defmodule Sibyl.UndefinedEventError do
  defexception [:message, :event, :module]

  @impl Exception
  def exception(event: event, module: module) do
    module_string = inspect(module)

    %Sibyl.UndefinedEventError{
      event: event,
      module: module,
      message: """
      Attempted to emit event `#{event}` defined in module `#{module_string}` but no such event was defined.
      Ensure `#{module_string}` uses `define_event/1` to define `#{event}` before emission.
      """
    }
  end
end

defmodule Sibyl.BadEmissionError do
  defexception [:message]

  @impl Exception
  def exception(module: module) do
    module_string = inspect(module)

    %Sibyl.BadEmissionError{
      message: """
      An event belonging to `#{module_string}` was attempted to be raised, but this module does not exist.

      Please assert that any module you try to emit an event from exists prior to to attempting to emit any events from it.
      """
    }
  end

  def exception(args: args) do
    args = inspect(args)

    %Sibyl.BadEmissionError{
      message: """
      Emitting events must be done either by `Sibyl.emit/4` or `Sibyl.emit/3` where:
      - `Sibyl.emit/4` takes a module alias as a first parameter, followed by an atom denoting the event name, an optional map of "measurements", and an optional map of "metadata".
      - `Sibyl.emit/3` takes either a bare atom or list of atoms (an event name), an optional map of "measurements", and an optional map of "metadata".

      No other argument combination is supported, but got: `#{args}`.
      """
    }
  end
end
