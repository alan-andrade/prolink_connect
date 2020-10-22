defmodule ProlinkConnect.Network do
  use GenServer

  alias ProlinkConnect.{Packet, Devices, Details}

  @hello 50_000
  @details 50_002

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, socket1} =
      :gen_udp.open(@hello, [
        :binary,
        {:broadcast, true},
        {:dontroute, true},
        {:active, true}
      ])

    {:ok, socket2} = :gen_udp.open(@details, [:binary, {:active, true}])

    sockets = %{
      @hello => socket1,
      @details => socket2
    }

    :gen_udp.controlling_process(socket1, self())
    :gen_udp.controlling_process(socket2, self())

    state =
      state
      |> Map.put(:sockets, sockets)
      |> Map.put(:devices, Devices.new())
      |> Map.put(:details, Details.new())

    {:ok, state}
  end

  def handle_info({:udp, _socket, _ip, @hello, packet}, %{devices: devices} = state) do
    with {:ok, %{channel: channel} = data} <- Packet.parse(packet) do
      new_devices = Devices.add_device(devices, channel, data)
      new_state = state |> Map.put(:devices, new_devices)
      {:noreply, new_state}
    else
      {:error, error} ->
        IO.inspect(error)
        {:noreply, state}
    end
  end

  def handle_info({:udp, _socket, _ip, _port, packet}, %{details: details} = state) do
    with {:ok, %{channel: channel} = data} <- Packet.parse(packet) do
      new_details = Details.set_status(details, channel, data)
      new_state = state |> Map.put(:details, new_details)
      {:noreply, new_state}
    else
      {:error, error} ->
        IO.inspect(error)
        {:noreply, state}
    end
  end

  def handle_cast({:send_keep_alive, packet}, %{sockets: sockets} = state) do
    socket = sockets[@hello]
    {address, packet} = packet
    :gen_udp.send(socket, address, @hello, packet)
    {:noreply, state}
  end

  def send_keep_alive(packet) do
    GenServer.cast(__MODULE__, {:send_keep_alive, packet})
  end
end
