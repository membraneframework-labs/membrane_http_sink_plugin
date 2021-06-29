defmodule Membrane.HTTP.Sink.Endpoint do
  import Plug.Conn
  require Logger

  @impl true
  def init(options) do
    Logger.debug("Initialized with options #{inspect(options)}")
    # initialize options
    Enum.into(options, %{})
  end

  @impl true
  def call(conn, options) do
    conn = send_chunked(conn, 200)
    send(options.pid, {:register, self()})
    conn = stream(conn)
    Logger.debug("Stream ended")
    send(options.pid, {:unregister, self()})
    conn
  end

  defp stream(conn) do
    receive do
      {:buffer, payload} ->
        case chunk(conn, payload) do
          {:ok, conn} ->
            stream(conn)

          {:error, :closed} ->
            conn

          error ->
            Logger.error("Unknown, terminating. #{inspect(error)}")
            conn
        end

      :eos ->
        Logger.debug("Received end of stream")
        conn
    end
  end
end
