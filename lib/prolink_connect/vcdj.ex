defmodule ProlinkConnect.VCDJ do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(cdj) do
    {:ok, cdj, {:continue, :boot}}
  end

  def handle_continue(:boot, state) do
    {:ok, {:interval, interval}} = :timer.send_interval(1_400, __MODULE__, :send_keep_alives)
    {:noreply, Map.put(state, :interval, interval)}
  end

  def handle_info(:send_keep_alives, cdj) do
    cdj.send_keep_alives.()
    {:noreply, cdj}
  end
end
