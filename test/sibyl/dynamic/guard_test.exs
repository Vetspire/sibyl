defmodule Sibyl.Dynamic.GuardsTest do
  use ExUnit.Case
  require Sibyl.Dynamic.Guards, as: Guards

  call_message = {:trace, self(), :call, {Enum, :map, [[], :some_function]}}
  return_message = {:trace, self(), :return_from, {Enum, :map, 2}, []}
  bad_messages = [:hello, "hello", 1, self(), DateTime.utc_now(), [], {1}, {:trace, :wrong_size}]

  describe "is_trace/1" do
    for {type, message} <- [call: call_message, return_from: return_message] do
      test "returns true given message that looks like it came from `:dbg.trace` of type #{type}" do
        assert Guards.is_trace(unquote(Macro.escape(message)))
      end
    end

    for message <- bad_messages do
      test "returns false given `#{inspect(message)}`" do
        refute Guards.is_trace({:hello})
      end
    end
  end

  describe "is_type/1" do
    for {type, message} <- [call: call_message, return_from: return_message] do
      test "returns true given message of type `#{type}` when asserting type `#{type}`" do
        assert Guards.is_type(unquote(Macro.escape(message)), unquote(type))
      end
    end

    for {type, message} <- [return_from: call_message, call: return_message] do
      test "returns false given message of any other type when asserting type `#{type}`" do
        refute Guards.is_type(unquote(Macro.escape(message)), unquote(type))
      end
    end
  end
end
