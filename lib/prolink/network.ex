# defmodule ProlinkConnect.Network do
#   use GenServer
# 
#   alias ProlinkConnect.{Packet, Channels, Details, Rekordbox, StatusDiff}
# 
#   @hello 50_000
#   @status 50_002
# 
#   def start_link(_) do
#     GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
#   end
# 
#   def init(state) do
#     {:ok, socket1} =
#       :gen_udp.open(@hello, [
#         :binary,
#         {:broadcast, true},
#         {:dontroute, true},
#         {:active, true}
#       ])
# 
#     {:ok, socket2} = :gen_udp.open(@status, [:binary, {:active, true}])
# 
#     sockets = %{
#       @hello => socket1,
#       @status => socket2
#     }
# 
#     :gen_udp.controlling_process(socket1, self())
#     :gen_udp.controlling_process(socket2, self())
# 
#     state =
#       state
#       |> Map.put(:sockets, sockets)
#       |> Map.put(:channels, Channels.new())
# 
#     {:ok, state}
#   end
# 
#   def handle_info({:udp, _socket, _ip, _port, packet}, %{channels: channels} = state) do
#     with {:ok, packet_type, data} <- Packet.parse(packet) do
#       new_channels = Channels.recv(channels, packet_type, data)
# 
#       case packet_type do
#         :keep_alive ->
#           new_channels = Channels.add_device(channels, channel, data)
#           new_state = state |> Map.put(:channels, new_channels)
#           {:noreply, new_state}
# 
#         :cdj_status ->
#           new_status = Details.set_status(status, channel, data)
#           device = Channels.get_device(channels, channel)
#           old_status = Map.get(status, channel)
#           incoming_status = Map.get(new_status, channel)
# 
#           if device && StatusDiff.diff(old_status, incoming_status) == :new_track do
#             Rekordbox.get_track_metadata(device, incoming_status, self())
#           end
# 
#           new_state = state |> Map.put(:status, new_status)
#           {:noreply, new_state}
#       end
#     else
#       {:error, error} ->
#         IO.inspect(error)
#         {:noreply, state}
#     end
#   end
# 
#   def handle_cast({:send_keep_alive, packet}, %{sockets: sockets} = state) do
#     socket = sockets[@hello]
#     {address, packet} = packet
#     :gen_udp.send(socket, address, @hello, packet)
#     {:noreply, state}
#   end
# 
#   def send_keep_alive(packet) do
#     GenServer.cast(__MODULE__, {:send_keep_alive, packet})
#   end
# 
#   def handle_call(:query, _from, state) do
#     {:reply, state}
#   end
# 
#   def query() do
#     GenServer.call(__MODULE__, :query)
#   end
# end
