defmodule ProlinkConnect.Listener do
  require Logger

  def accept(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, {:active, false}])
    Logger.info("Accepting connections on port #{port}")
    loop_reception(socket)
  end

  defp loop_reception(socket) do
    {:ok, {address, port, packet}} = :gen_udp.recv(socket, 0)
    Logger.info("Received packet: \n #{packet}")
    loop_reception(socket)
  end
end
