defmodule ProlinkConnect.VCDJ.Status do
  use GenServer

  alias ProlinkConnect.Packet

  @port 50_002

  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, {:active, true}])
    :gen_udp.controlling_process(socket, self())

    {
      :ok,
      state
    }
  end

  def query, do: GenServer.call(__MODULE__, :query)

  def handle_info({:udp, _socket, _ip, _port, packet}, state) do
    {:noreply, process_packet(packet, state)}
  end

  defp process_packet(packet, state) do
    with {:ok, new_packet} <- Packet.parse(packet) do
      old_packet = Map.get(state, new_packet.channel, %{})
      packet_diff = Packet.diff(old_packet, new_packet)
      handle_packet_updates(packet_diff, old_packet)

      Map.put(state, new_packet.channel, new_packet)
    else
      {:error, error} ->
        IO.inspect(error)
        state
    end
  end

  defp handle_packet_updates(diff, old_packet) do
    with {:ok, track_id} <- Map.fetch(diff, :rekordbox_id) do
      # Rekordbox.get_track_metadata(track_id, old_packet.channel)
    end
  end
end
