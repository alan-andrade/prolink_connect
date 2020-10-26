defmodule ProlinkConnect.Rekordbox do
  use GenServer
  require Logger

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
      {:ok, socket} = :gen_tcp.connect(device.ip, 1051, [])
      :gen_tcp.controlling_process(socket, self())
      new_state = Map.put(state, device.ip, socket)
      {:noreply, new_state}
    else
      process_pending_requests(state)
      {:noreply, state}
    end
  end

  def process_pending_requests(%{requests: reqs} = state) do
    Enum.each(reqs, &GenServer.cast(__MODULE__, &1))
  end

  @impl true
  def handle_cast({:track_info, device, status, from}, state) do
    socket = state[device.ip]
    :ok = :gen_tcp.send(socket, <<0x11>>)
    {:noreply, state}
  end

  def handle_cast({:enqueue, request}, state) do
    new_requests = [request | state.requests]
    new_state = %{state | requests: new_requests}
    {:noreply, new_state}
  end

  def get_track_metadata(device, status, from) do
    # Can this spawn another function to fetch the things ?
    GenServer.cast(__MODULE__, {:enqueue, {:track_info, device, status, from}})
  end

  def ensure_connected(device) do
    GenServer.cast(__MODULE__, {:ensure_connected, device})
  end
end
