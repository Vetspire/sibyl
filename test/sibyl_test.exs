defmodule SibylTest do
  use ExUnit.Case
  use Sibyl

  define_event(:defined)

  describe "emit/3" do
    test "emits events so long as they're defined in this module" do
      assert :ok = Sibyl.emit(:defined)
    end

    test "raises a compile-time error when trying to emit an event that isn't defined" do
      assert_raise ArgumentError, fn ->
        Code.eval_string("""
        defmodule SibylTestCompilationHooks do
          use Sibyl

          def hello do
            Sibyl.emit(:not_defined)
          end
        end
        """)
      end
    end
  end
end
