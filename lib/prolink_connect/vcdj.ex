defmodule ProlinkConnect.VCDJ do
  use GenServer

  def init(_) do
    {:ok, iface} = iface()
    {:ok, {:interval, interval}} = :timer.send_interval(1_500, __MODULE__, :send_keep_alives)
    {:ok, %{name: vcdj_name(), channel: vcdj_channel(), iface: iface, interval: interval}}
  end

  def start_link(cdj) do
    GenServer.start_link(__MODULE__, cdj, name: __MODULE__)
  end

  defp iface() do
    read_env(:iface) |> ProlinkConnect.Iface.find()
  end

  defp vcdj_name do
    read_env(:vcdj_name)
  end

  defp vcdj_channel do
    read_env(:vcdj_channel)
  end

  defp read_env(key) do
    Application.fetch_env!(:prolink_connect, key)
  end

  def handle_info(:send_keep_alives, cdj) do
    ProlinkConnect.Network.send(
      cdj.iface |> ProlinkConnect.Iface.broadcast_addr(),
      50_000,
      keep_alive_packet(cdj)
    )

    {:noreply, cdj}
  end

  def keep_alive_packet(cdj) do
    ProlinkConnect.Packet.create_keep_alive(cdj.iface, cdj.name, cdj.channel)
  end
end
