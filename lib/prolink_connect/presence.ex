defmodule ProlinkConnect.Presence do
  alias ProlinkConnect.{Socket, Packet, Iface}

  use GenServer

  @port 50_000

  def start_link(_) do
    iface = Iface.find!()

    vcdj = %{
      name: Application.fetch_env!(:prolink_connect, :cdj_name),
      channel: Application.fetch_env!(:prolink_connect, :cdj_channel)
    }

    {:ok, socket} = Socket.open(@port)

    GenServer.start_link(
      __MODULE__,
      %{
        iface: iface,
        vcdj: vcdj,
        socket: socket,
        devices: %{}
      },
      name: __MODULE__
    )
  end

  def init(state) do
    {:ok, state, {:continue, :start_listening}}
  end

  def query, do: GenServer.call(__MODULE__, :query)

  def handle_continue(:start_listening, state) do
    {:ok, {:interval, timer1}} = :timer.send_interval(1_500, __MODULE__, :listen)
    {:ok, {:interval, timer2}} = :timer.send_interval(1_500, __MODULE__, :broadcast)
    {:noreply, state |> Map.put(:timers, [timer1, timer2])}
  end

  def handle_info(:listen, %{socket: socket} = state) do
    with {:ok, packet} <- Socket.read(socket, 1_400),
         {:ok, device} <- Packet.parse(packet) do
      new_devices =
        Map.put(
          state.devices,
          device.channel,
          Map.put(device, :received_at, Time.utc_now())
        )

      {:noreply, Map.put(state, :devices, new_devices)}
    else
      {:error, :timeout} -> {:noreply, state}
      {:error, :packet_unkown} -> {:noreply, state}
      {:error, error} -> raise(error)
    end
  end

  def handle_info(:broadcast, %{socket: socket, iface: iface, vcdj: vcdj} = state) do
    packet = Packet.create_keep_alive(iface, vcdj.name, vcdj.channel)
    Socket.send(socket, Iface.broadcast_addr(iface), packet)
    {:noreply, state}
  end

  def handle_call(:query, _from, state) do
    {:reply, state.devices, state}
  end
end
