defmodule Sibyl.Dynamic.Guards do
  @moduledoc """
  Utils module contianing various custom guards in the scope of `Sibyl.Dynamic`
  """

  @doc """
  Returns `true` if given term is a message sent by the Erlang `:dbg` module for
  function and function-return traces.
  """
  defguard trace?(message)
           when elem(message, 0) == :trace and
                  (tuple_size(message) == 4 or
                     tuple_size(message) == 5)

  @doc """
  Returns `true` if given term is a message sent by the Erlang `:dbg` module and if
  the message type corresponds to the given type.
  """
  defguard type?(message, type) when elem(message, 2) == type
end
