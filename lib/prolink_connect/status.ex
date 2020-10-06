defmodule ProlinkConnect.Status do
  alias ProlinkConnect.Packet

  use GenServer

  @port 50_002

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{channels: %{}}, name: __MODULE__)
  end

  def init(state) do
    {:ok, socket} =
      :gen_udp.open(@port, [:binary, {:broadcast, true}, {:dontroute, true}, {:active, true}])

    {
      :gen_udp.controlling_process(socket, self()),
      state
    }
  end

  def query, do: GenServer.call(__MODULE__, :query)

  def handle_info({:udp, _socket, _ip, _port, packet}, state) do
    with {:ok, status} <- Packet.parse(packet) do
      updated_channels =
        Map.put(
          state.channels,
          status.channel,
          status
        )

      {:noreply, Map.put(state, :channels, updated_channels)}
    else
      {:error, :timeout} ->
        {:noreply, state}

      {:error, error} ->
        IO.inspect(error)
        {:noreply, state}
    end
  end

  def handle_call(:query, _from, state) do
    {:reply, state.channels, state}
  end
end
