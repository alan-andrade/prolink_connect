defmodule ProlinkConnect.VCDJ.Connect do
  use GenServer

  alias ProlinkConnect.{Network, VCDJ}

  def start_link(_) do
    GenServer.start_link(__MODULE__, {}, name: __MODULE__)
  end

  def init(state) do
    {:ok, {:interval, timer}} = :timer.send_interval(1_500, __MODULE__, :broadcast)
    {:ok, {timer}}
  end

  def handle_info(:broadcast, state) do
    Network.send_keep_alive(VCDJ.packet_keep_alive())
    {:noreply, state}
  end
end
