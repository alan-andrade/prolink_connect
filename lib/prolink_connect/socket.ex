defmodule ProlinkConnect.Socket do
  def open(port) do
    :gen_udp.open(port, [:binary, {:broadcast, true}, {:dontroute, true}, {:active, false}])
  end

  def send(socket, host, packet) do
    :gen_udp.send(socket, host, port(socket), packet)
  end

  def read(socket, timeout \\ 500) do
    case :gen_udp.recv(socket, 0, timeout) do
      {:ok, {_, _, packet}} -> {:ok, packet}
      {:error, error} -> {:error, error}
    end
  end

  defp port(socket) do
    {:ok, port} = :inet.port(socket)
    port
  end
end
