defmodule ProlinkConnect.Watcher do
  use GenServer

  def init(_) do
    {:ok, {:interval, devices}} = :timer.send_interval(1_500, __MODULE__, :watch_devices)
    {:ok, {:interval, status}} = :timer.send_interval(50, __MODULE__, :watch_status)
    {:ok, %{devices: devices, status: status}}
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def handle_info(:watch_devices, state) do
    read_socket(50_000) |> parse_packet() |> handle_packet() |> update_db()
    {:noreply, state}
  end

  def handle_info(:watch_status, state) do
    read_socket(50_002) |> parse_packet() |> handle_packet() |> update_db()
    {:noreply, state}
  end

  defp read_socket(port) do
    ProlinkConnect.Network.read_from(port)
  end

  defp parse_packet({:ok, packet}) do
    ProlinkConnect.Packet.parse(packet)
  end

  defp parse_packet(error), do: error

  defp handle_packet({:keep_alive, device}) do
    {:keep_alive, %{device | last_received: Time.utc_now()}}
  end

  defp handle_packet({:cdj_status, status}) do
    {:cdj_status, status}
  end

  defp handle_packet(error), do: error

  defp update_db(update) do
    ProlinkConnect.DB.update(update)
  end

  defp update_db({:error, error}) do
    IO.inspect(error)
  end
end
