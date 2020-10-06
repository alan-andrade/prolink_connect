defmodule ProlinkConnect.Presence do
  alias ProlinkConnect.{Packet, Iface}

  use GenServer

  @port 50_000

  def start_link(_) do
    iface = Iface.find!()

    vcdj = %{
      name: Application.fetch_env!(:prolink_connect, :cdj_name),
      channel: Application.fetch_env!(:prolink_connect, :cdj_channel)
    }

    GenServer.start_link(
      __MODULE__,
      %{
        iface: iface,
        vcdj: vcdj,
        devices: %{}
      },
      name: __MODULE__
    )
  end

  def init(state) do
    {:ok, socket} =
      :gen_udp.open(@port, [:binary, {:broadcast, true}, {:dontroute, true}, {:active, true}])

    {
      :gen_udp.controlling_process(socket, self()),
      Map.put(state, :socket, socket),
      {:continue, :start_broadcasting}
    }
  end

  def query, do: GenServer.call(__MODULE__, :query)

  def handle_continue(:start_broadcasting, state) do
    {:ok, {:interval, timer}} = :timer.send_interval(1_500, __MODULE__, :broadcast)
    {:noreply, state |> Map.put(:timers, [timer])}
  end

  def handle_info({:udp, _socket, _ip, _port, packet}, state) do
    with {:ok, device} <- Packet.parse(packet) do
      new_devices =
        Map.put(
          state.devices,
          device.channel,
          Map.put(device, :received_at, Time.utc_now())
        )

      {:noreply, Map.put(state, :devices, new_devices)}
    else
      {:error, error} ->
        IO.inspect(error)
        {:noreply, state}
    end
  end

  def handle_info(:broadcast, %{socket: socket, iface: iface, vcdj: vcdj} = state) do
    packet = Packet.create_keep_alive(iface, vcdj.name, vcdj.channel)
    :gen_udp.send(socket, Iface.broadcast_addr(iface), @port, packet)
    {:noreply, state}
  end

  def handle_call(:query, _from, state) do
    {:reply, state.devices, state}
  end
end
