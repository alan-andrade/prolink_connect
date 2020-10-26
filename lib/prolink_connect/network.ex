defmodule ProlinkConnect.Network do
  use GenServer

  alias ProlinkConnect.{Packet, Channels, Details, Rekordbox, StatusDiff}

  @hello 50_000
  @status 50_002

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

    {:ok, socket2} = :gen_udp.open(@status, [:binary, {:active, true}])

    sockets = %{
      @hello => socket1,
      @status => socket2
    }

    :gen_udp.controlling_process(socket1, self())
    :gen_udp.controlling_process(socket2, self())

    state =
      state
      |> Map.put(:sockets, sockets)
      |> Map.put(:channels, Channels.new())
      |> Map.put(:status, Details.new())

    {:ok, state}
  end

  def handle_info({:udp, _socket, _ip, @hello, packet}, %{channels: channels} = state) do
    with {:ok, %{channel: channel} = data} <- Packet.parse(packet) do
      new_channels = Channels.add_device(channels, channel, data)
      new_state = state |> Map.put(:channels, new_channels)
      {:noreply, new_state}
    else
      {:error, error} ->
        IO.inspect(error)
        {:noreply, state}
    end
  end

  def handle_info(
        {:udp, _socket, _ip, _port, packet},
        %{status: status, channels: channels} = state
      ) do
    with {:ok, %{channel: channel} = data} <- Packet.parse(packet) do
      new_status = Details.set_status(status, channel, data)

      case StatusDiff.diff(status[channel], new_status[channel]) do
        :new_track ->
          Rekordbox.get_track_metadata(channels[channel].device, new_status[channel], self())

        :noop ->
          Rekordbox.ensure_connected(channels[channel].device)
      end

      new_state = state |> Map.put(:status, new_status)
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
