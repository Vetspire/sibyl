defmodule Sibyl.AST do
  @moduledoc """
  Utility module for working with ASTs
  """

  @type ast() :: term()
  @type module_ast() :: {:__aliases__, term(), [atom()]} | atom()
  @type unused() :: :__unused__

  @doc """
  Returns true if the given argument is an Elixir AST node representing a module alias
  such as `Enum`.
  """
  defguard is_module_ast(ast)
           when is_atom(ast) or
                  (is_tuple(ast) and tuple_size(ast) == 3 and elem(ast, 0) == :__aliases__)

  @doc """
  Returns true if the given argument is equal to `:__unused__`. Primarily used internally.
  """
  defguard unused?(term) when term == :__unused__

  @doc """
  Returns the `:__unused__` atom.
  """
  @spec unused() :: ast()
  defmacro unused do
    quote do
      :__unused__
    end
  end

  # coveralls-ignore-start
  # TODO: find a way to unit test this, as we now expect the macro's env to be
  # passed in
  @doc """
  Given an alias AST node, returns the fully resolved alias that said node would expand
  to.

  For example, given: `{:__aliases, unused(), [Elixir, Enum]}`, returns: `Enum`.
  """
  @spec module(module_ast(), Macro.Env.t()) :: module()
  def module({:__aliases__, _metadata, _module_list} = ast, env) do
    case Macro.expand(ast, env) do
      module when is_atom(module) ->
        module

      otherwise ->
        otherwise = inspect(otherwise)
        raise ArgumentError, "expected an alias expanding to a module, got: #{otherwise}"
    end
  end
end
