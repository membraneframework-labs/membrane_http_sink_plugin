defmodule Membrane.HTTP.Sink.Endpoint do
  import Plug.Conn
  require Logger

  @spec init(keyword()) :: map()
  def init(options) do
    options
  end

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(conn, _options) do
    [stream_id] = conn.path_info

    if stream_exists(stream_id) do
      send_chunked(conn, 200)
      |> stream(stream_id)
    else
      send_resp(conn, 404, "Stream doesn't exist")
    end
  end

  defp stream(conn, stream_id) do
    register(stream_id)
    conn = do_stream(conn)
    unregister()
    conn
  end

  defp do_stream(conn) do
    receive do
      {:buffer, payload} ->
        case chunk(conn, payload) do
          {:ok, conn} ->
            do_stream(conn)

          {:error, :closed} ->
            conn
        end

      :eos ->
        conn
    end
  end

  defp stream_exists(name) do
    Registry.match(Membrane.HTTP.Registry, :stream, name)
    |> Enum.any?()
  end

  defp register(name) do
    Logger.debug("Registering #{inspect(self())} to stream `#{name}`")
    Registry.register(Membrane.HTTP.Registry, :client, name)
  end

  defp unregister() do
    Registry.unregister(Membrane.HTTP.Registry, :client)
  end
end
