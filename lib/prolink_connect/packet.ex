defmodule ProlinkConnect.Packet do
  require Logger

  @header <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>

  def parse(<<@header, 0x6, rest::binary>>) do
    {:keep_alive, rest |> parse_keep_alive}
  end

  def parse(<<@header, 0x0A, rest::binary>>) do
    {:cdj_status, rest |> parse_cdj_status}
  end

  def parse(<<@header, _packet_type, rest::binary>>) do
    {:not_implemented, rest}
  end

  def parse({:error, e}) do
    {:error, e}
  end

  def parse_keep_alive(<<0x0, name::binary-size(20), rest::binary>>) do
    channel = :binary.at(rest, 0x04)
    device_type = :binary.at(rest, 0x05)
    ip = :binary.bin_to_list(rest, {0x06, 6})

    %{name: name, device_type: device_type, ip: ip, channel: channel}
  end

  def parse_cdj_status(<<_name::binary-size(20), 0x1, rest::binary>>) do
    channel = :binary.at(rest, 0x1)
    status = Integer.to_string(:binary.at(rest, 0x69), 16)
    isMaster = :binary.at(rest, 0x7E)
    rekordbox = :binary.bin_to_list(rest, {0x70, 4})

    if channel == 1 do
      rest
      |> :binary.bin_to_list()
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.map(&String.pad_trailing(&1, 4))
      |> Enum.map(&"#{&1},")
      |> Enum.chunk_every(16)
      |> Enum.join("\n")
      |> Logger.debug()
    end

    %{status: status, channel: channel, rekordbox: rekordbox, isMaster: isMaster}
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
