defmodule ProlinkConnect.Watcher do
  require Logger

  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state, {:continue, :boot}}
  end

  def handle_continue(:boot, state) do
    {:ok, {:interval, device_interval}} = :timer.send_interval(1_000, __MODULE__, :watch_devices)
    new_state = Map.put(state, :device_interval, device_interval)

    {:ok, {:interval, status_interval}} = :timer.send_interval(50, __MODULE__, :watch_status)
    new_state = Map.put(new_state, :status_interval, status_interval)

    {:noreply, new_state}
  end

  def handle_info(:watch_devices, state) do
    state.read_announcements.() |> parse_packet() |> handle_packet() |> update_db()
    {:noreply, state}
  end

  def handle_info(:watch_status, state) do
    state.read_status.() |> parse_packet() |> handle_packet() |> update_db()
    {:noreply, state}
  end

  defp parse_packet({:ok, packet}) do
    ProlinkConnect.Packet.parse(packet)
  end

  defp parse_packet(error), do: error

  defp handle_packet({:keep_alive, device}) do
    {:keep_alive, ProlinkConnect.Device.new(device)}
  end

  defp handle_packet({:cdj_status, status}) do
    {:cdj_status, ProlinkConnect.DeviceStatus.new(status)}
  end

  defp handle_packet(error), do: error

  defp update_db({:error, error}) do
    Logger.debug(error |> to_string)
  end

  defp update_db(update) do
    ProlinkConnect.DB.update(update)
  end
end
