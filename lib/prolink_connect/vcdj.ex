defmodule ProlinkConnect.VCDJ do
  alias ProlinkConnect.{Iface, Packet}

  @name Application.fetch_env!(:prolink_connect, :cdj_name)
  @channel Application.fetch_env!(:prolink_connect, :cdj_channel)
  @iface_name Application.fetch_env!(:prolink_connect, :iface_name)
  @iface Iface.find!(@iface_name)
  @keep_alive Packet.create_keep_alive(@iface, @name, @channel)

  def name, do: @name
  def channel, do: @channel
  def iface, do: @iface
  def packet_keep_alive, do: @keep_alive
end
