# defmodule ProlinkConnect.Channels do
#   def new(), do: %{}
# 
#   def recv(state, :keep_alive, packet) do
#     new_channels = Channels.add_device(channels, channel, data)
#     new_state = state |> Map.put(:channels, new_channels)
#     {:noreply, new_state}
#   end
# 
#   def recv(state, :cdj_status, packet) do
#   end
# 
#   def add_device(state, channel, device, timestamp \\ Time.utc_now()) do
#     state
#     |> Map.put(channel, %{device: device, last_seen: timestamp})
#   end
# 
#   def get_device(state, channel) do
#     state
#     |> Map.get(channel, %{})
#     |> Map.get(:device)
#   end
# 
#   def prune(state) do
#     stale_devices =
#       state
#       |> Stream.filter(fn record ->
#         value = elem(record, 1)
#         Time.diff(value[:last_seen], Time.utc_now()) < -3
#       end)
#       |> Enum.map(&elem(&1, 0))
# 
#     Map.drop(state, stale_devices)
#   end
# 
#   def all(state), do: Map.values(state) |> Enum.map(&Map.get(&1, :device))
# end
