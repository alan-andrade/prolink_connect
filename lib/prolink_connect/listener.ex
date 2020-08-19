defmodule ProlinkConnect.Listener do
  require Logger

  @header_bytes <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>

  def accept(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, {:active, false}])
    Logger.info("Accepting connections on port #{port}")
    loop_reception(socket)
  end

  defp loop_reception(socket) do
    {:ok, {_address, _port, packet}} = :gen_udp.recv(socket, 0)
    Logger.info("New UDP packet received: \n#{packet}")
    parse_packet(packet)
    loop_reception(socket)
  end

  defp parse_packet(
         <<@header_bytes, packet_kind::size(8), device_type::size(8),
           device_name::binary-size(20), 0x01, 0x02, packet_length::size(8)-unit(2),
           packet_number::binary>>
       ) do
    Logger.info("packet_kind #{packet_kind}")
    Logger.info("device type #{device_type}")
    Logger.info("device name #{String.replace(device_name, "^@", "")}")
    Logger.info("packet length #{packet_length}")
    Logger.info("packet number #{packet_number}")
  end

  defp parse_packet(packet) do
    Logger.info("unidentified packet: #{packet}")
  end

  # All packets begin with these 10 bytes.
  # This is followed by a byte which (combined with the port on which it was received) identifies what kind of information is found in the packet.
  # 51 73 70 74 31 57 6d 4a 4f 4c
  #
  # Port 5000 Packets
  # Announce devices present on the network, and negotiate device ID.
  #
  # 00  First-stage channel number claim, e.g. mixers and CDJs.
  # 01  Mixer assignment intention, sent by mixers to devices connected to channel-specific ports.
  # 02  Second-stage channel number claim, e.g. mixers and CDJs.
  # 03  Mixer channel assignment, sent by mixers to devices connected to channel-specific ports.
  # 04  Final-stage channel number claim, e.g. mixers and CDJs.
  # 05  Mixer assignment finished, sent by mixers to devices connected to channel-specific ports.
  # 06  Device keep-alive (still present on network), e.g. mixers and CDJs.
  # 08  Channel Conflict, sent when a device sees another trying to claim the same channel.
  # 0a  Initial device announcement, e.g. mixers and CDJs.
  #
  # Port 5001 Packets
  # Beat synchronization and mixer features.
  #
  # 02	Fader Start
  # 03	Channels On Air
  # 26	Master Handoff Request
  # 27	Master Handoff Response
  # 28	Beat
  # 2a	Sync Control
  #
  #
  # Port 5002 Packets
  # Device status, what track is playing, tempo, how much has been played, remote control.
  # 05	Media Query
  # 06	Media Response
  # 0a	CDJ Status
  # 19	Load Track Command
  # 1a	Load Track Acknowledgment
  # 29	Mixer Status
  # 34	Load Settings Command
end
