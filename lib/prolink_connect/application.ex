defmodule ProlinkConnect.Application do
  use Application

  def start(_, config) do
    {:ok, announcements_socket} = ProlinkConnect.Socket.open(50_000)
    {:ok, status_socket} = ProlinkConnect.Socket.open(50_002)

    {:ok, iface} =
      Application.fetch_env!(:prolink_connect, :iface_name)
      |> ProlinkConnect.Iface.find()

    name = Application.fetch_env!(:prolink_connect, :cdj_name)
    channel = Application.fetch_env!(:prolink_connect, :cdj_channel)

    send_keep_alives = fn ->
      ProlinkConnect.Socket.send(
        announcements_socket,
        iface |> ProlinkConnect.Iface.broadcast_addr(),
        ProlinkConnect.Packet.create_keep_alive(iface, name, channel)
      )
    end

    read_announcements = fn ->
      ProlinkConnect.Socket.read(announcements_socket)
    end

    read_status = fn ->
      ProlinkConnect.Socket.read(status_socket)
    end

    children = [
      {ProlinkConnect.VCDJ, %{send_keep_alives: send_keep_alives}},
      {ProlinkConnect.Watcher,
       %{
         read_announcements: read_announcements,
         read_status: read_status
       }},
      {ProlinkConnect.DB, %{devices: %{}, status: %{}}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
