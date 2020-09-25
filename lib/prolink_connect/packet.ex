defmodule ProlinkConnect.Packet do
  @header <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>

  def parse(<<@header, 0x6, rest::binary>>) do
    {:keep_alive, rest |> parse_keep_alive}
  end

  def parse(<<@header, 0x0A, rest::binary>>) do
    {:cdj_status, rest |> parse_cdj_status}
  end

  def parse(<<@header, packet_type, rest::binary>>) do
    {:not_implemented, rest}
  end

  def parse({:error, e}) do
    {:error, e}
  end

  def parse_keep_alive(
        <<0x0, name::binary-size(20), 0x1, _remainder, _length::binary-size(2), channel,
          device_type, _mac::binary-size(6), ip::binary-size(4), _rest::binary>>
      ) do
    ProlinkConnect.Device.new(name, device_type, ip, channel)
  end

  def parse_cdj_status(
        <<name::binary-size(20), 0x1, _subtype, _device_number, _length::binary-size(2), channel,
          0x0, 0x0, _activity, _track_loaded_on_device, _track_loaded_on_slot, _track_type, 0x0,
          rekordbox::binary-size(4), _gargabe::binary-size(87), status, rest::binary>>
      ) do
    %{status: status, channel: channel, rekordbox: rekordbox}
  end

  def create_keep_alive(iface, device_name, channel) do
    mac = iface |> ProlinkConnect.Iface.hwaddr()
    ip = iface |> ProlinkConnect.Iface.ipv4addr()

    p = @header
    p = [p, <<0x6, 0x0>>]
    p = [p, String.pad_trailing(device_name, 20, <<0x0>>)]
    p = [p, <<0x01, 0x02, 0x00, 0x36>>]
    p = [p, :binary.encode_unsigned(channel)]
    p = [p, <<0x01>>]
    p = [p, mac]
    p = [p, ip]
    p = [p, <<0x01, 0x00, 0x00, 0x00, 0x01, 0x00>>]
    p
  end
end
