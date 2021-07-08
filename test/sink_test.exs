defmodule Membrane.HTTP.Sink.Test do
  use ExUnit.Case

  @registry Membrane.HTTP.Registry
  @plug Membrane.HTTP.Sink.Endpoint
  @port 5000
  @stream_key "t"

  defmodule Generator do
    use Membrane.Source

    def_output_pad :output,
      availability: :always,
      caps: :any,
      mode: :pull

    @impl true
    def handle_init(_opts) do
      {:ok, %{}}
    end

    @impl true
    def handle_demand(:output, size, :buffers, _ctx, state) do
      Process.sleep(10)

      buffers =
        for _i <- 1..size,
            do: %Membrane.Buffer{
              payload: :crypto.strong_rand_bytes(8) |> :base64.encode_to_string()
            }

      {{:ok, buffer: {:output, buffers}}, state}
    end
  end

  defmodule TestPipeline do
    use Membrane.Pipeline

    @impl true
    def handle_init(_opts) do
      spec = %ParentSpec{
        children: [
          source: Generator,
          sink: %Membrane.HTTP.Sink{port: 5000}
        ],
        links: [
          link(:source) |> via_in(Pad.ref(:input, "t")) |> to(:sink)
        ]
      }

      {{:ok, spec: spec}, %{}}
    end
  end

  setup_all do
    {:ok, pid} = TestPipeline.start_link()
    TestPipeline.play(pid)
  end

  test "Registry is up" do
    Registry.count(@registry)
  end

  test "Stream is registered" do
    assert Registry.match(@registry, :stream, @stream_key) |> Enum.any?()
  end

  test "registry entry is removed when client disconnects" do
    {:ok, conn} = Mint.HTTP.connect(:http, "localhost", 5000)
    {:ok, conn, _} = Mint.HTTP.request(conn, "GET", "/t", [], nil)

    Process.sleep(500)
    assert Registry.match(@registry, :client, @stream_key) |> Enum.any?()
    Mint.HTTP.close(conn)
    Process.sleep(500)
    refute Registry.match(@registry, :client, @stream_key) |> Enum.any?()
  end
end
