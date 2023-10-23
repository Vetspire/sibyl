defmodule Sibyl.Dynamic do
  @moduledoc """
  Module which contains functions which allow you to bridge together the built in
  BEAM debugging and tracer with modules implementing the `Sibyl.Handler` behaviour.

  This provides extremely powerful functionality as you can effectively instruct
  the BEAM to start building OpenTelemetry traces without code instrumentation on
  production environments.

  It is important to note that leveraging the BEAM's built in debugging and tracing
  functionality can have severe memory and CPU requirements so it isn't something
  one should do lightly.

  Regardless, in order to track down heisenbugs and other maladies which can only
  be reproduced on production environments, this functionality should prove extremely
  useful.
  """

  import Sibyl.Dynamic.Guards

  alias Sibyl.Events
  alias Sibyl.Handlers.Logger

  @state __MODULE__

  @spec enable(sibyl_handler :: module()) :: {:ok, term()}
  def enable(handler \\ Logger) do
    # Init some global state that we need so that we can communicate with our debugger
    :ok = init_ets()
    :ok = put_handler!(handler)

    # Flush :dbg in case it was already started prior to this.
    :ok = :dbg.stop()
    {:ok, _pid} = :dbg.start()

    # This is the important bit; by default :dbg will just log what gets traced on stdout
    # but we actually need to handle these traces because we want to capture that the
    # function was called programmatically rather than reading it off the shell/log file
    # This tells `:dbg` to call the `handle_trace/2` function in the current running process
    # whenever we get a trace message
    {:ok, _pid} = :dbg.tracer(:process, {&handle_trace/2, []})

    # And this sets up `:dbg` to handle function calls
    :dbg.p(:all, [:call])
  end

  @spec disable() :: :ok
  def disable do
    :ok = :dbg.stop()
    :ets.delete(@state)
    :ok
  rescue
    _exception -> :ok
  end

  @spec trace(module(), function :: atom(), arity :: integer()) :: {:ok, term()}
  def trace(m, f, a) do
    # :dbg.tpl traces all function calls including private functions (which we needed for our use-case)
    # but I think it's a good default
    #
    # The 4th parameter basically says to trace all invocations of the given mfa (`:_` means we pattern
    # match on everything), and we also pass in `{:return_trace}` to tell the tracer we want to receive
    # not just function invocation messages but also capture the return of those functions
    :dbg.tpl(m, f, a, [{:_, [], [{:return_trace}]}])
  end

  # TODO: eventually to trace on a deployed system, we're going to want to be able to have a
  # DynamicSupervisor and individual light-weight GenServer's running traces for each PID.
  #
  # Otherwise, traces from one process will end traces of another because everything is
  # currently run on the current process only.
  #
  # This will be easy enough to do; but for now, this works.
  @doc false
  @spec handle_trace(term(), stack :: list()) :: list()
  def handle_trace(message, stack) when is_trace(message) and is_type(message, :call) do
    {module, function, arity} = parse_mfa!(message)

    module
    |> Events.build_event(function, arity, :start)
    |> get_handler!().handle_event(%{args: parse_args!(message)}, %{}, name: @state)

    stack
  end

  def handle_trace(message, stack) when is_trace(message) and is_type(message, :return_from) do
    {module, function, arity} = parse_mfa!(message)
    return = parse_return!(message)

    module
    |> Events.build_event(function, arity, :stop)
    |> get_handler!().handle_event(%{return_value: return}, %{}, name: @state)

    stack
  end

  # coveralls-ignore-start
  # This isn't meant to be called, so we don't bother testing it.
  def handle_trace(_message, stack) do
    stack
  end

  # coveralls-ignore-stop

  defp parse_mfa!({_message_type, _pid, _trace_type, {module, function, args}}) do
    {module, function, length(args)}
  end

  defp parse_mfa!({_message_type, _pid, _trace_type, {module, function, arity}, _return}) do
    {module, function, arity}
  end

  defp parse_args!({_message_type, _pid, _trace_type, {_module, _function, args}}) do
    args
  end

  defp parse_return!({_message_type, _pid, _trace_type, _mfa, return}) do
    return
  end

  defp init_ets do
    if :ets.whereis(@state) == :undefined do
      :ets.new(@state, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end

  defp put_handler!(handler) do
    :ets.insert(@state, {:handler, handler})
    :ok
  end

  defp get_handler! do
    [{:handler, handler}] = :ets.lookup(@state, :handler)
    handler
  end
end
