defmodule ProlinkConnect.Rekordbox do
  use GenServer
  alias ProlinkConnect.Network

  def start_link(_) do
    GenServer.start_link(
      __MODULE__,
      %{
        requests: []
      },
      name: __MODULE__
    )
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:ensure_connected, device}, state) do
    socket = state[device.ip]

    if socket == nil do
      {:ok, socket} = :gen_tcp.connect(device.ip, 1051, [{:active, true}])
      :gen_tcp.controlling_process(socket, self())
      new_state = Map.put(state, device.ip, socket)
      IO.inspect("tcp connected")
      IO.inspect(socket)
      {:noreply, new_state}
    else
      process_pending_requests(state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:track_info, device, status, from}, state) do
    socket = state[device.ip]

    case :gen_tcp.send(socket, <<0x11>>) do
      :ok ->
        IO.inspect("SENT, remove request")
        {:noreply, state}

      {:error, _} ->
        ensure_connected(device)
        nil
    end
  end

  def process_pending_requests(%{requests: reqs}) do
    Enum.each(reqs, &GenServer.cast(__MODULE__, &1))
  end

  @impl true
  def handle_cast({:enqueue, request}, state) do
    new_requests = [request | state.requests]
    new_state = %{state | requests: new_requests}
    {:noreply, new_state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    # Rekordbox.ensure_connected()
    IO.inspect("TCP CLOSED")
    IO.inspect(socket)
    {:noreply, state}
  end

  def get_track_metadata(device, status, from) do
    GenServer.cast(__MODULE__, {:enqueue, {:track_info, device, status, from}})
  end

  def ensure_connected(device) do
    GenServer.cast(__MODULE__, {:ensure_connected, device})
  end

  def refresh() do
    Network.query()
  end
end
