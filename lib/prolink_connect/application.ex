defmodule ProlinkConnect.Application do
  use Application

  def start(_, _) do
    children = [
      # Read/Write Server to interact with the network
      ProlinkConnect.Network,

      # Send Keep Alives, Track Requests
      ProlinkConnect.VCDJ,

      # Watches the network for incoming UDP packets
      ProlinkConnect.Watcher,

      # DB of devices on the network
      ProlinkConnect.DB

      # Interface for the system
      # ProlinkConnect.Main
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
