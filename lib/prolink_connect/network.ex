defmodule ProlinkConnect.Network do
  use GenServer

  def init(_) do
    {:ok, socket_0} = open(50_000)
    {:ok, socket_1} = open(50_001)
    {:ok, socket_2} = open(50_002)

    {:ok,
     %{
       50_000 => socket_0,
       50_001 => socket_1,
       50_002 => socket_2
     }}
  end

  def start_link(sockets) do
    GenServer.start_link(__MODULE__, sockets, name: __MODULE__)
  end

  def read_from(port) do
    GenServer.call(__MODULE__, {:read, port})
  end

  def handle_call({:read, port}, _from, sockets) do
    {:reply, sockets |> Map.fetch!(port) |> read, sockets}
  end

  def handle_call({:write, {host, port, packet}}, _from, sockets) do
    out_socket = sockets |> Map.fetch!(50_000)
    {:reply, :gen_udp.send(out_socket, host, port, packet), sockets}
  end

  defp open(port) do
    :gen_udp.open(port, [:binary, {:broadcast, true}, {:dontroute, true}, {:active, false}])
  end

  def send(host, port, packet) do
    GenServer.call(__MODULE__, {:write, {host, port, packet}})
  end

  defp read({:ok, {_, _, packet}}), do: {:ok, packet}
  defp read({:error, error}), do: {:error, error}

  defp read(socket) do
    read(:gen_udp.recv(socket, 1, 1_500))
  end
end
