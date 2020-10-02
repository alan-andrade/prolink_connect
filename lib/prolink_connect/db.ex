defmodule ProlinkConnect.DB do
  require Logger
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def query() do
    GenServer.call(__MODULE__, :query)
  end

  def update({:keep_alive, device}) do
    GenServer.cast(__MODULE__, {:update, {:keep_alive, device}})
  end

  def update({:cdj_status, status}) do
    GenServer.cast(__MODULE__, {:update, {:status, status}})
  end

  def update(msg) do
    Logger.error("Unexpected update intent")
    Logger.error(msg)
  end

  def handle_call(:query, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:update, {:keep_alive, device}}, state = %{devices: devices}) do
    {
      :noreply,
      %{state | devices: Map.put(devices, device.channel, device)}
    }
  end

  def handle_cast({:update, {:status, status}}, state) do
    {
      :noreply,
      %{state | status: Map.put(state.status, status.channel, status)}
    }
  end
end
