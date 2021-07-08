defmodule Membrane.HTTP.Sink do
  @moduledoc """
  Sink working in Publisher - Subscriber model. To find keys related to sinks, take a look at `outputs/0` and `outputs/1`
  """
  use Membrane.Sink
  require Membrane.Logger

  def_options port: [
                spec: 1..65_535,
                default: 4000,
                description: """
                Port on which the HTTP Server will be served.
                """
              ],
              protocol_options: [
                spec: keyword(),
                default: [idle_timeout: :infinity]
              ]

  def_input_pad :input,
    availability: :on_request,
    caps: :any,
    demand_unit: :buffers

  @registry Membrane.HTTP.Registry
  @plug Membrane.HTTP.Sink.Endpoint

  @impl true
  def handle_init(%__MODULE__{port: port, protocol_options: options}) do
    {:ok, pid} = Plug.Cowboy.http(@plug, [], port: port, protocol_options: options)
    Process.link(pid)
    {:ok, %{}}
  end

  @impl true
  def handle_prepared_to_playing(ctx, state) do
    demands =
      ctx.pads
      |> Map.to_list()
      |> Enum.filter(fn
        {_key, %{direction: :input}} -> true
        _else -> false
      end)
      |> Enum.map(&Bunch.key/1)
      |> Enum.flat_map(&[demand: &1])

    {{:ok, demands}, state}
  end

  @impl true
  def handle_write(Pad.ref(:input, name) = pad, buffer, _ctx, state) do
    dispatch({:buffer, buffer.payload}, name)

    {{:ok, demand: pad}, state}
  end

  @impl true
  def handle_end_of_stream(Pad.ref(:input, name), _ctx, state) do
    dispatch(:eos, name)
    Plug.Cowboy.shutdown(@plug)

    {:ok, state}
  end

  @impl true
  def handle_pad_added(Pad.ref(:input, name) = ref, ctx, state) when is_binary(name) do
    if String.to_charlist(name) |> Enum.any?(&URI.char_reserved?/1) do
      raise("Name `#{name}` contains HTTP reserved characters and therefore cannot be used.")
    else
      Registry.register(@registry, :stream, name)
      Membrane.Logger.debug("Connected pad #{inspect(ref)}")

      if ctx.playback_state == :playing do
        {{:ok, demand: ref}, state}
      else
        {:ok, state}
      end
    end
  end

  def handle_pad_added(Pad.ref(:input, name), _ctx, _state) do
    raise("`#{inspect(name)}` is not a binary. It wouldn't make a correct URL")
  end

  @impl true
  def handle_pad_removed(Pad.ref(:input, name) = ref, _ctx, state) do
    dispatch(:eos, name)
    :ok = Registry.unregister_match(@registry, :stream, name)
    Membrane.Logger.debug("Disconnected pad #{inspect(ref)}")
    {:ok, state}
  end

  @spec dispatch(any(), map()) :: :ok
  defp dispatch(message, stream) do
    Registry.match(@registry, :client, stream)
    |> Enum.map(&Bunch.key/1)
    |> Enum.each(&send(&1, message))

    :ok
  end
end
