defmodule Sibyl.AST do
  @moduledoc """
  Utility module for working with ASTs
  """

  @type ast() :: term()
  @type alias() :: {:__aliases__, term(), [atom()]}
  @type unused() :: :__unused__

  @doc """
  Returns true if the given argument is an Elixir AST node representing a module alias
  such as `Enum`.
  """
  defguard alias?(ast) when is_tuple(ast) and elem(ast, 0) == :__aliases__

  @doc """
  Returns true if the given argument is equal to `:__unused__`. Primarily used internally.
  """
  defguard unused?(term) when term == :__unused__

  @doc """
  Given an alias AST node, returns the fully resolved alias that said node would expand
  to.

  For example, given: `{:__aliases, unused(), [Elixir, Enum]}`, returns: `Enum`.
  """
  @spec module(alias()) :: module()
  def module({:__aliases__, _metadata, module_list}) do
    Module.safe_concat(module_list)
  end

  @doc """
  Returns the `:__unused__` atom.
  """
  @spec unused() :: ast()
  defmacro unused do
    quote do
      :__unused__
    end
  end
end
