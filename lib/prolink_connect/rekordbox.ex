defmodule ProlinkConnect.Rekordbox do
  use GenServer
  alias ProlinkConnect.Status

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    init_port()
  end

  defp init_port do
  end

  def track_info(track) do
  end
end
