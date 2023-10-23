defmodule Sibyl.Plugin do
  @moduledoc """
  Open interface for defining custom Sibyl plugins.

  Note that at the time of writing, all plugins are considered in-development features and no
  stability or fixed API is guaranteed.

  Sibyl Plugins are intended to be used by providing them as an option when attaching
  Sibyl handlers like so:

  ```
  :ok = Sibyl.Handlers.attach_all_events(plugins: [Sibyl.Plugins.Absinthe])
  :ok = Sibyl.Handlers.attach_module_events(MyApp.Module, plugins: [Sibyl.Plugins.Absinthe])
  :ok = Sibyl.Handlers.attach_events([[:my_app, :start]], plugins: [Sibyl.Plugins.Absinthe])
  ```

  Implementing a plugin is done by defining a module which `use`s `Sibyl.Plugin` and implements
  the behaviour below.

  Please feel free to refer to `Sibyl.Plugins.Absinthe` or `Sibyl.Plugins.Ecto` for examples of
  how to implement a plugin.
  """

  alias Sibyl.Events

  defmacro __using__(_opts) do
    prefix =
      __MODULE__
      |> Module.split()
      |> Enum.map(
        &(&1
          |> String.downcase()
          # NOTE: the following is done at compile time so should be safe
          # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
          |> String.to_atom())
      )

    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def prefix, do: unquote(prefix)

      @impl unquote(__MODULE__)
      def identity, do: unquote(Enum.join(prefix, "-"))

      @impl unquote(__MODULE__)
      def stop, do: :telemetry.detach(identity())

      defoverridable prefix: 0, identity: 0, stop: 0
    end
  end

  @doc "Event prefix for events emitted/proxied by a given plugin implementation. Defaults to the module's name split"
  @callback prefix :: [atom()]

  @doc "Unique ID for the plugin. Intended to be used as a mechanism for attaching/detaching proxy `:telemetry` handlers"
  @callback identity :: String.t()

  @doc "Called by Sibyl when attaching a plugin to a handler. Should return a list of events which should be listened to by handlers"
  @callback init(opts :: Keyword.t()) :: [Events.event()]

  @doc "Stops and cleans up any resources used by the plugin. Intended primarily for `:telemetry` handler detachment"
  @callback stop :: :ok | {:error, term()}
end
