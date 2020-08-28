defmodule ProlinkConnect.OldFinder do
  require Logger
  @port 50_000

  def start(client) do
    {:ok, socket} = :gen_udp.open(@port, [:binary, {:active, false}])

    spawn_link(fn ->
      loop_reception(socket, client)
    end)
  end

  defp loop_reception(socket, client) do
    {:ok, {_address, _port, packet}} = :gen_udp.recv(socket, 0)
    send(client, parse_packet(packet))
    loop_reception(socket, client)
  end

  # All packets begin with these 10 bytes.
  @header_bytes <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>
  @is_cdj <<0x01>>
  @is_mixer <<0x02>>

  # Initial device announcement, e.g. mixers and CDJs. 
  @announcement <<0x0A>>
  defp parse_packet(<<
         @header_bytes,
         @announcement,
         0x00,
         device_name::binary-size(20),
         0x01,
         0x02,
         packet_length::binary-size(2),
         device_type
       >>) do
    {:announcement, {device_type, device_name}}
  end

  # First-stage channel number claim, e.g. mixers and CDJs.
  @channel_claim_1 <<0x00>>
  defp parse_packet(<<
         @header_bytes,
         @channel_claim_1,
         0x00,
         device_name::binary-size(20),
         0x01,
         0x02,
         packet_length::binary-size(2),
         packet_counter,
         device_type,
         mac_address::binary-size(6)
       >>) do
    {:channel_claim_1, {device_type, device_name, mac_address}}
  end

  # Mixer assignment intention, sent by mixers to devices connected to channel-specific ports.
  @assignment_intention <<0x01>>

  # Second-stage channel number claim, e.g. mixers and CDJs.
  @channel_claim_2 <<0x02>>
  defp parse_packet(<<
         @header_bytes,
         @channel_claim_2,
         0x00,
         device_name::binary-size(20),
         0x01,
         0x02,
         packet_length::binary-size(2),
         ip_address::binary-size(4),
         mac_address::binary-size(6),
         device_number,
         packet_counter,
         device_type,
         auto_assign
       >>) do
    Logger.info("second stage chanel claim")
    Logger.info("device number: #{device_number}")
    Logger.info("ip address #{ip_address}")
    Logger.info("mac address #{mac_address}")
    Logger.info("auto: #{auto_assign}")
    {:channel_claim_2, {device_type, device_name, mac_address, ip_address, device_number}}
  end

  # Mixer channel assignment, sent by mixers to devices connected to channel-specific ports.
  @channel_assigned <<0x03>>

  # Final-stage channel number claim, e.g. mixers and CDJs.
  @channel_claim_3 <<0x04>>
  defp parse_packet(<<
         @header_bytes,
         @channel_claim_3,
         0x00,
         device_name::size(8)-unit(20),
         0x01,
         0x02,
         packet_length::size(8)-unit(2),
         device_number::size(8),
         packet_counter::size(8)
       >>) do
    Logger.info("third stage chanel claim")
    Logger.info("device number: #{device_number}")
    {:channel_claim_3, {device_name, device_number}}
  end

  # Mixer assignment finished, sent by mixers to devices connected to channel-specific ports.
  @mixer_assigned <<0x05>>

  # Device keep-alive (still present on network), e.g. mixers and CDJs.
  @keep_alive <<0x06>>
  defp parse_packet(<<
         @header_bytes,
         @keep_alive,
         0x00,
         device_name::binary-size(20),
         0x01,
         0x02,
         packet_length::binary-size(2),
         device_number,
         device_type,
         mac_address::binary-size(6),
         ip_address::binary-size(4),
         rest::binary
       >>) do
    Logger.info("Keep alive. device #{device_number}, type: #{device_type}")
    <<a, b, c, d>> = ip_address
    Logger.info("ip: #{Enum.join([a, b, c, d], ".")}")
    {:keep_alive, {device_type, device_name, device_number, mac_address, ip_address}}
  end

  # Channel Conflict, sent when a device sees another trying to claim the same channel.
  @channel_conflict <<0x08>>

  defp parse_packet(packet) do
    Logger.info("unidentified packet: #{packet}")
  end
end
