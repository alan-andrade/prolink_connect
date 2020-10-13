defmodule ProlinkConnect.VCDJ.Presence do
  alias ProlinkConnect.Packet

  use GenServer

  @port 50_000

  # packet, broadcast_addr
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, socket} =
      :gen_udp.open(@port, [:binary, {:broadcast, true}, {:dontroute, true}, {:active, true}])

    {:ok, {:interval, timer}} = :timer.send_interval(1_500, __MODULE__, :broadcast)
    :gen_udp.controlling_process(socket, self())

    new_state =
      Map.put(state, :socket, socket)
      |> Map.put(:timer, timer)
      |> Map.put(:devices, [])

    {:ok, new_state}
  end

  def query, do: GenServer.call(__MODULE__, :query)

  def handle_info({:udp, _socket, _ip, _port, packet}, state) do
    with {:ok, device} <- Packet.parse(packet) do
      new_device = Map.put(device, :received_at, Time.utc_now())
      new_state = Map.put(state, :devices, clean_stale_devices([new_device | state.devices]))
      {:noreply, new_state}
    else
      {:error, error} ->
        IO.inspect(error)
        {:noreply, state}
    end
  end

  def handle_info(
        :broadcast,
        %{socket: socket, broadcast_addr: addr, packet: packet} = state
      ) do
    :gen_udp.send(socket, addr, @port, packet)
    {:noreply, state}
  end

  def handle_call(:query, _from, state) do
    {:reply, state.devices, state}
  end

  defp clean_stale_devices(devices) do
    Enum.reduce(devices, [], fn device, acc ->
      last_received = Map.get(device, :received_at)
      time_diff = Time.diff(Time.utc_now(), last_received, :second)

      if time_diff < 3 do
        [device | acc]
      else
        acc
      end
    end)
  end
end
