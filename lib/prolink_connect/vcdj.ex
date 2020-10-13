defmodule ProlinkConnect.VCDJ do
  use GenServer

  alias ProlinkConnect.{Iface, Packet}
  alias ProlinkConnect.VCDJ.{Presence, Status}

  defstruct [:name, :channel, :iface]

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    vcdj = %ProlinkConnect.VCDJ{
      name: name(),
      channel: channel(),
      iface: iface()
    }

    {:ok, %{vcdj: vcdj}, {:continue, :connect}}
  end

  def handle_continue(:connect, %{vcdj: vcdj} = state) do
    {:ok, presence_pid} =
      Presence.start_link(%{
        packet: Packet.create_keep_alive(vcdj.iface, vcdj.name, vcdj.channel),
        broadcast_addr: Iface.broadcast_addr(vcdj.iface)
      })

    {:ok, status_pid} = Status.start_link()

    new_state =
      Map.put(state, :pesence_pid, presence_pid)
      |> Map.put(:status_pid, status_pid)

    {:noreply, new_state}
  end

  defp name, do: Application.fetch_env!(:prolink_connect, :cdj_name)
  defp channel, do: Application.fetch_env!(:prolink_connect, :cdj_channel)
  defp iface_name, do: Application.fetch_env!(:prolink_connect, :iface_name)
  defp iface, do: Iface.find!(iface_name())
end
