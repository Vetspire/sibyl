defmodule Sibyl.Handlers.DecoratorTests do
  use ExUnit.Case

  defmodule MyApp.DecoratorTestOne do
    use Sibyl

    @decorate_all trace()

    def test_1(_a), do: 15

    def test_2(a) when a > 44, do: :big
    def test_2(_a), do: :small

    def test_3(_a = 12), do: :big
    def test_3(10 = _a), do: :small

    def test_4(a, _b, c = 1), do: {a, c}
    def test_4(_a, b, c = 2), do: {b, c}
    def test_4(a, b = 3, _c), do: {a, b}

    def test_5(%{a: _, b: 12}), do: 12
    def test_5([1, 2, 3, _ | _rest]), do: 99

    def test_6({1, 2, 3, _, [_], %{b: _}}), do: :wow

    def test_7(%DateTime{} = _datetime), do: 12
  end

  # This file would fail to compile if the above module produced any warnings,
  # so this test just needs to assert that it runs.
  test "compiles without warnings", do: assert(true)
end
