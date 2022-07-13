defmodule SibylTest do
  use ExUnit.Case

  describe "emit/3" do
    test "raises a compile-time error when trying to emit an event that isn't defined" do
      assert_raise Sibyl.UndefinedEventError, fn ->
        Code.eval_string("""
        defmodule SibylTestCompilationHooks1 do
          use Sibyl

          def hello do
            emit :not_defined
          end
        end
        """)
      end
    end

    test "does not raise a compile-time error when emitting an event that is defined" do
      assert Code.eval_string("""
             defmodule SibylTestCompilationHooks2 do
               use Sibyl

               define_event :defined

               def hello do
                 emit :defined
               end
             end
             """)
    end

    test "does not raise a compile-time error when emitting an event that is a list of atoms" do
      assert Code.eval_string("""
             defmodule SibylTestCompilationHooks3 do
               use Sibyl

               def hello do
                 emit [:some, :random, :event]
               end
             end
             """)
    end
  end

  describe "emit/4" do
    test "raises a compile-time error when trying to emit an event that isn't defined" do
      assert_raise Sibyl.UndefinedEventError, fn ->
        Code.eval_string("""
        defmodule Emit4Test1 do
          use Sibyl
        end

        defmodule SibylTestCompilationHooks4 do
          use Sibyl

          def hello do
            emit Emit4Test1, :not_defined
          end
        end
        """)
      end
    end

    test "does not raise a compile-time error when emitting an event that is defined" do
      assert Code.eval_string("""
             defmodule Emit4Test2 do
               use Sibyl
               define_event :defined
             end

             defmodule SibylTestCompilationHooks5 do
               use Sibyl

               def hello do
                 emit Emit4Test2, :defined
               end
             end
             """)
    end

    test "raises a compile time error if called any other way" do
      assert_raise Sibyl.BadEmissionError, fn ->
        Code.eval_string("""
        defmodule SibylTestCompilationHooks6 do
          use Sibyl

          def hello do
            emit 123, :not_defined
          end
        end
        """)
      end
    end

    test "does not raise a compile-time error when emitting an event that is defined via alias" do
      assert Code.eval_string("""
             defmodule Emit4Test3 do
               use Sibyl
               define_event :defined
             end

             defmodule SibylTestCompilationHooks7 do
               use Sibyl

               alias Emit4Test3, as: Test

               def hello do
                 emit Test, :defined
               end
             end
             """)
    end

    test "raises compile time error if module does not exist" do
      assert_raise Sibyl.BadEmissionError, fn ->
        Code.eval_string("""
        defmodule SibylTestCompilationHooks6 do
          use Sibyl

          def hello do
            emit SomeModuleThatDoesNotExist, :not_defined
          end
        end
        """)
      end
    end
  end
end
