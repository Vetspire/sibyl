defmodule Sibyl.Application do
  @moduledoc false

  use Application

  # coveralls-ignore-start
  @impl Application
  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one, name: Sibyl.Supervisor)
  end
end
