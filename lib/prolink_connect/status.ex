defmodule ProlinkConnect.Status do
  alias ProlinkConnect.{Socket, Packet}

  use GenServer

  @port 50_002

  def start_link(_) do
    {:ok, socket} = Socket.open(@port)

    state = %{
      socket: socket,
      channels: %{}
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state, {:continue, :start_listening}}
  end

  def query, do: GenServer.call(__MODULE__, :query)

  def handle_continue(:start_listening, state) do
    {:ok, {:interval, timer}} = :timer.send_interval(50, __MODULE__, :listen)
    {:noreply, Map.put(state, :timer, timer)}
  end

  def handle_info(:listen, %{socket: socket} = state) do
    with {:ok, packet} <- Socket.read(socket, 40),
         {:ok, status} <- Packet.parse(packet) do
      updated_channels =
        Map.put(
          state.channels,
          status.channel,
          status
        )

      {:noreply, Map.put(state, :channels, updated_channels)}
    else
      {:error, :timeout} -> {:noreply, state}
      {:error, :packet_unkown} -> {:noreply, state}
      {:error, error} -> raise(error)
    end
  end

  def handle_call(:query, _from, state) do
    {:reply, state.channels, state}
  end
end
