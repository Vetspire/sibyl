defmodule Sibyl.Handlers.ASTTest do
  use ExUnit.Case
  require Sibyl.AST, as: AST

  describe "alias?/1" do
    test "returns true when given an AST node which is an alias" do
      assert AST.alias?({:__aliases__, [line: 16], [MyApp, Users]})
    end

    test "returns false given anything else" do
      refute AST.alias?(:atom)
    end
  end

  describe "unused?/1" do
    test "returns true when given `:__unused__`" do
      assert AST.unused?(:__unused__)
    end

    test "returns false when given anything else" do
      refute AST.unused?(nil)
    end
  end

  describe "unused/0" do
    test "returns `:__unused__`" do
      assert :__unused__ = AST.unused()
    end
  end
end
