defmodule ProlinkConnect.Application do
  use Application

  def start(_, _) do
    children = [
      ProlinkConnect.VCDJ
    ]

    # Spliting the code into servers that listen to a specific
    # port has been a design that has felt more idiomatic mainly
    # because the design is cenetered around udp ports.
    #
    # In order to query track metadata it's necessary to introduce
    # tcp ports and the design starts to now feel innapropiate.
    #
    # In order to query the server for track metadata it's necessary
    # to know about connected devices. Eventhough this information
    # can be known by asking directly to Presence.query() or
    # Status.query(), it does bring a problem of dependencies.
    #
    # In order for a possible Rekordbox server to work, it requires
    # devices ip, stablish an initial connection and keep track of
    # requests ID's. It would feel dumb if I code a Rekordbox
    # server that just `waits` for a device to be online.
    #
    # This opens up the idea of having a VCDJ process which will
    # be considered a direct analogue of a real CDJ. It will have 
    # a process to read other devices on the network. It will also
    # have a process to capture other devices status. It will
    # have a rekordbox process so queries can be made using other
    # CDJS on the network address.
    #
    # ---
    #
    # Review:
    #
    # Spawn a process per device present in the network.
    #
    # cdj comes alive // This is a network reader / coordinador
    #   pid already alive for chanel X ?
    #     spawn new()
    #       proc has a rekordbox
    #
    # Spawn a VCDJ
    #   Broadcast keep alives / presence.
    #   Read other devices status.
    #

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
