defmodule ProlinkConnect.Rekordbox do
  use GenServer
  alias ProlinkConnect.Status

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def handle_call({:track_info, status}, _from, state) do
  end

  def get_track_metadata(status) do
    # Can this spawn another function to fetch the things ?
    GenServer.call(__MODULE__, {:track_info, status})
  end
end
