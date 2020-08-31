defmodule ProlinkConnect do
  defmodule Socket do
    def open(port) do
      {:ok, socket} = :gen_udp.open(port, [:binary, {:broadcast, true}, {:dontroute, true}])
      socket
    end

    def send(socket, host, port, packet) do
      :gen_udp.send(socket, host, port, packet)
    end

    def set_controlling_process(socket, pid) do
      :gen_udp.controlling_process(socket, pid)
    end
  end

  defmodule Device do
    defstruct [:name, :ip, :device_type, :last_received]

    def new(name, type, ip) do
      %__MODULE__{
        name: name |> to_charlist |> Enum.filter(&(&1 != 0)) |> to_string,
        ip: ip,
        device_type: type,
        last_received: Time.utc_now()
      }
    end
  end

  defmodule Packet do
    @header <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>

    def parse(<<@header, packet_type, 0x0, rest::binary>>) do
      case packet_type do
        0x6 -> {:keep_alive, rest |> parse_keep_alive}
        _ -> {:not_implemented}
      end
    end

    def parse(data) do
      {:error, :packet_unkown}
    end

    def parse_keep_alive(
          <<name::binary-size(20), 0x1, remainder, length::binary-size(2), packet_count,
            device_type, mac::binary-size(6), ip::binary-size(4), rest::binary>>
        ) do
      Device.new(name, device_type, ip)
    end

    def create_keep_alive(mac, ip) do
      <<
        @header,
        0x06,
        0x00,
        "HELLO SEAHORSE CDJ..",
        0x01,
        0x02,
        0x00,
        0x36,
        0x00,
        # device number
        # 0x04,
        0x01
      >> <>
        mac <>
        ip <>
        <<0x01, 0x00, 0x00, 0x00, 0x01, 0x00>>
    end
  end

  defmodule Iface do
    def find(name) do
      {:ok, interfaces} = :inet.getifaddrs()
      interfaces |> Enum.filter(fn {iname, opts} -> iname == name end) |> List.first()
    end

    def broadcast_addr({name, opts}) do
      opts[:broadaddr]
    end

    def hwaddr({name, opts}) do
      opts[:hwaddr]
      |> Enum.map(&(&1 |> :binary.encode_unsigned()))
      |> Enum.join()
    end

    def ipv4addr({name, opts}) do
      Keyword.get_values(opts, :addr)
      |> List.last()
      |> Tuple.to_list()
      |> Enum.map(&(&1 |> :binary.encode_unsigned()))
      |> Enum.join()
    end
  end

  defmodule VCDJ do
    use GenServer

    def init(state), do: {:ok, state}

    def start_link(state \\ %{}) do
      GenServer.start_link(__MODULE__, state, name: __MODULE__)
    end

    def handle_cast(:connect, state) do
      Socket.send(
        state.socket,
        get_destination(state.iface),
        50_000,
        create_packet(state.iface)
      )

      Process.send_after(self(), :send_keep_alive, 500)
      {:noreply, state}
    end

    def handle_info(:send_keep_alive, state) do
      __MODULE__.connect()
      {:noreply, state}
    end

    def connect, do: GenServer.cast(__MODULE__, :connect)

    defp get_destination(iface) do
      Iface.find(iface) |> Iface.broadcast_addr()
    end

    defp create_packet(iface) do
      iface = Iface.find(iface)
      mac = Iface.hwaddr(iface)
      ip = Iface.ipv4addr(iface)

      Packet.create_keep_alive(mac, ip)
    end
  end

  defmodule DeviceFinder do
    use GenServer

    def init(state), do: {:ok, state}

    def start_link(state \\ %{}) do
      GenServer.start_link(__MODULE__, state, name: __MODULE__)
    end

    def handle_call(:query, _from, state), do: {:reply, state, state}

    def handle_cast({:receive_packet, {:keep_alive, device}}, state) do
      new_state =
        Map.update(
          state,
          device.ip,
          device,
          &%{&1 | last_received: Time.utc_now()}
        )

      {:noreply, new_state}
    end

    def query, do: GenServer.call(__MODULE__, :query)
    def receive_packet(packet), do: GenServer.cast(__MODULE__, {:receive_packet, packet})
  end

  defmodule NetworkListener do
    def start(socket) do
      pid = spawn_link(NetworkListener, :read, [])
      socket |> Socket.set_controlling_process(pid)
    end

    def read() do
      receive do
        {_udp, socket, _ip, _port, packet} ->
          DeviceFinder.receive_packet(Packet.parse(packet))
      end

      read()
    end
  end

  def start() do
    DeviceFinder.start_link()

    socket = Socket.open(50_000)
    NetworkListener.start(socket)
    VCDJ.start_link(%{iface: 'en4', socket: socket})
    VCDJ.connect()
    query_loop()
  end

  def query_loop do
    IO.inspect(DeviceFinder.query())
    Process.sleep(1500)
    query_loop()
  end
end
