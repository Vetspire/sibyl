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
  """

  alias Sibyl.Events

  @callback identity :: String.t()
  @callback init(opts :: Keyword.t()) :: [Events.event()]
  @callback stop :: :ok | {:error, term()}
end
