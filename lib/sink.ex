defmodule Membrane.HTTP.Sink do
  @moduledoc """
  Sink working in Publisher - Subscriber model. To find keys related to sinks, take a look at `outputs/0` and `outputs/1`
  """
  use Membrane.Sink
  require Membrane.Logger

  def_input_pad :input,
    availability: :always,
    caps: :any,
    demand_unit: :buffers

  @registry Membrane.HTTP.Registry

  @impl true
  def handle_init(_opts) do
    name = generate_name()
    Registry.register(@registry, {:stream, name}, :ok)

    {:ok, %{registered_as: name}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, demand: :input}, state}
  end

  @impl true
  def handle_write(pad, buffer, _ctx, state) do
    broadcast({:buffer, buffer.payload}, state)
    Process.sleep(24)

    {{:ok, demand: pad}, state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    broadcast(:eos, state)

    {:ok, state}
  end

  @spec broadcast(any(), map()) :: :ok
  defp broadcast(message, state) do
    Registry.dispatch(@registry, {:client, state.registered_as}, fn entries ->
      for {pid, _} <- entries, do: send(pid, message)
    end)

    :ok
  end

  defp generate_name() do
    key = for(_i <- 1..10, do: :crypto.rand_uniform(?a, ?z)) |> :erlang.list_to_binary()

    if {:stream, key} in outputs() do
      generate_name()
    else
      key
    end
  end

  @doc """
  Returns a list of endpoint keys pointing to valid streams
  """
  @spec outputs() :: [String.t()]
  def outputs() do
    Registry.select(Membrane.HTTP.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.filter(&(Bunch.key(&1) == :stream))
    |> Enum.map(&Bunch.value/1)
  end

  @doc """
  Returns an endpoint key pointing to the sink running on the given PID
  """
  @spec output(pid()) :: String.t()
  def output(pid) do
    Registry.keys(Membrane.HTTP.Registry, pid)
    |> Enum.map(&Bunch.value/1)
    |> hd()
  end
end
