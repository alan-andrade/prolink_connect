defmodule ProlinkConnect.DB do
  use GenServer

  def init(_) do
    {:ok, %{devices: %{}, status: %{}}}
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def update({:keep_alive, device}) do
    GenServer.cast(__MODULE__, {:update, {:keep_alive, device}})
  end

  def update({:cdj_status, status}) do
    GenServer.cast(__MODULE__, {:update, {:status, status}})
  end

  def update(_) do
    IO.puts("Unexpected update intent")
  end

  def handle_cast({:update, {:keep_alive, device}}, state) do
    {
      :noreply,
      %{state | devices: Map.put(state.devices, device.channel, device)}
    }
  end

  def handle_cast({:update, {:status, status}}, state) do
    {
      :noreply,
      %{state | status: Map.put(state.status, status.channel, status)}
    }
  end
end
