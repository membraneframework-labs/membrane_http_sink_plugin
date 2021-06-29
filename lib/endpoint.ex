defmodule Membrane.HTTP.Sink.Endpoint do
  import Plug.Conn
  require Logger

  @spec init(keyword()) :: map()
  def init(options) do
    Enum.into(options, %{})
  end

  @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def call(conn, options) do
    send_chunked(conn, 200)
    |> stream(options)
  end

  defp stream(conn, %{sink_pid: sink}) do
    send(sink, {:register, self()})
    conn = do_stream(conn)
    send(sink, {:unregister, self()})
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
end
