defmodule Membrane.HTTP.Sink do
  @moduledoc """
  Sink working in Publisher - Subscriber model
  """
  use Membrane.Sink
  require Membrane.Logger

  def_input_pad :input,
    availability: :always,
    caps: :any,
    demand_unit: :buffers

  @impl true
  def handle_init(_opts) do
    {:ok, _} = Plug.Cowboy.http(Membrane.HTTP.Sink.Endpoint, [pid: self()], port: 4002)
    {:ok, %{connections: MapSet.new()}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, demand: :input}, state}
  end

  @impl true
  def handle_write(pad, buffer, _ctx, state) do
    state.connections
    |> Enum.each(&send(&1, {:buffer, buffer.payload}))

    {{:ok, demand: pad}, state}
  end

  @impl true
  def handle_other({:register, pid}, _ctx, state) do
    Membrane.Logger.debug("Registering connection from #{inspect(pid)}")
    {:ok, state |> Map.update!(:connections, &MapSet.put(&1, pid))}
  end

  def handle_other({:unregister, pid}, _ctx, state) do
    Membrane.Logger.debug("Unregistering connection from #{inspect(pid)}")
    {:ok, state |> Map.update!(:connections, &MapSet.delete(&1, pid))}
  end

  def handle_other(message, _ctx, state) do
    Membrane.Logger.error("Received unknown message #{inspect(message)}")
    {:ok, state}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    state.connections
    |> Enum.each(fn pid -> send(pid, :eos) end)

    {:ok, state}
  end
end
