defmodule ProlinkConnect do
  alias ProlinkConnect.{Finder, CastKeepAlive, DeviceStatus}
  require Logger

  # Finder / Scanner
  #   Scans the 50_000 for udp packets and finds connected devices.
  #   Reports back with status
  # Devices
  #   Keeps track of connected devices via message passing from the scanner.
  # VCDJ
  #   Bind to 50_002 so you can start listening to incoming packets
  #   Send keep alive packets to 50_000

  def start(iface_name) when is_list(iface_name) do
    iface_name |> find_iface |> start
  end

  def start(iface) do
    finder = spawn_link(Finder, :start, [])
  end

  defp find_iface(iface_name) do
    {:ok, ifaces} = :inet.getifaddrs()

    Enum.filter(ifaces, fn {name, opts} ->
      name == iface_name
    end)
    |> List.first()
  end
end

defmodule Device do
  defstruct [:name, :number, :ip]

  def new(name, number, ip) do
    %__MODULE__{name: name, number: number, ip: ip}
  end
end

defmodule ProlinkConnect.Finder do
  require Logger

  defmodule Listener do
    def listen(finder) do
      device_data =
        receive do
          {_udp, _socket, _ip, _port, packet} -> parse_packet(packet)
          {:error, error} -> Logger.info("error: #{error}")
        after
          2000 ->
            Logger.warn("No CDJs in network...")
        end

      send(finder, device_data)
      listen(finder)
    end

    @header_bytes <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>
    def parse_packet(
          <<@header_bytes, 0x06, 0x00, device_name::binary-size(20), 0x01, 0x02,
            packet_length::binary-size(2), device_number, device_type,
            mac_address::binary-size(6), ip_address::binary-size(4), rest::binary>>
        ) do
      {:keep_alive, Device.new(device_name, device_number, ip_address)}
    end

    def parse_packet() do
      Logger.info("Unkown packet")
    end
  end

  def start do
    open_socket |> listen
    receive_msg
  end

  defp receive_msg do
    receive do
      msg -> Logger.info("#{msg}")
    end

    receive_msg
  end

  defp open_socket do
    {:ok, socket} = :gen_udp.open(50_000, [:binary])
    socket
  end

  defp listen(socket) do
    :gen_udp.controlling_process(socket, spawn_link(Listener, :listen, [self()]))
    socket
  end
end

defmodule ProlinkConnect.CastKeepAlive do
  @header_bytes <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>

  def broadcast(socket, iface) do
    {_name, opts} = iface

    packet_t =
      packet(
        opts[:hwaddr]
        |> Enum.map(&(&1 |> :binary.encode_unsigned()))
        |> Enum.join(),
        Keyword.get_values(opts, :addr)
        |> List.last()
        |> Tuple.to_list()
        |> Enum.map(&(&1 |> :binary.encode_unsigned()))
        |> Enum.join()
      )

    :ok =
      :gen_udp.send(
        socket,
        opts[:broadaddr],
        50_000,
        packet_t
      )

    Process.sleep(1500)
    broadcast(socket, iface)
  end

  defp packet(mac, ip) when is_binary(mac) and is_binary(ip) do
    <<
      @header_bytes,
      0x06,
      0x00,
      "HELLO SEAHORSE CDJ 12",
      0x01,
      0x02,
      0x36,
      # channel
      0x04,
      0x01
    >> <>
      mac <>
      ip <>
      <<0x01, 0x00, 0x00, 0x00, 0x01, 0x00>>
  end
end
