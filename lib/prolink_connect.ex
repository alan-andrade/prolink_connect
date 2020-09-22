defmodule ProlinkConnect do
  defmodule Socket do
    use GenServer

    def init(state), do: {:ok, state}

    def start_link(port) do
      {:ok, socket} =
        :gen_udp.open(port, [:binary, {:broadcast, true}, {:dontroute, true}, {:active, false}])

      GenServer.start_link(__MODULE__, %{socket: socket, port: port})
    end

    def handle_cast({:send, host, port, packet}, state) do
      :gen_udp.send(state.socket, host, port, packet)
      {:noreply, state}
    end

    def handle_call(:read, _from, state) do
      case :gen_udp.recv(state.socket, 5, 1_500) do
        {:ok, {_, _, packet}} -> {:reply, packet, state}
        _ -> {:reply, <<>>, state}
      end
    end

    def handle_call(:port, _from, state) do
      {:reply, state.port, state}
    end

    def send(pid, host, port, packet) do
      GenServer.cast(pid, {:send, host, port, packet})
    end

    def read(pid) do
      GenServer.call(pid, :read)
    end

    def port(pid) do
      GenServer.call(pid, :port)
    end
  end

  defmodule Device do
    defstruct [:name, :ip, :device_type, :channel, :last_received]

    def new(name, type, ip, channel) do
      %__MODULE__{
        name: name |> clean,
        ip: ip,
        device_type: type,
        channel: channel,
        last_received: Time.utc_now()
      }
    end

    defp clean(name) do
      name |> to_charlist |> Enum.filter(&(&1 != 0)) |> to_string
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

  defmodule Packet do
    @header <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>

    def parse(<<@header, packet_type, rest::binary>>) do
      case packet_type do
        0x6 -> {:keep_alive, rest |> parse_keep_alive}
        0x0A -> {:cdj_status, rest |> parse_cdj_status}
        _ -> {:not_implemented}
      end
    end

    def parse(data) do
      {:error, :packet_unkown}
    end

    def parse_keep_alive(
          <<0x0, name::binary-size(20), 0x1, _remainder, _length::binary-size(2), channel,
            device_type, mac::binary-size(6), ip::binary-size(4), _rest::binary>>
        ) do
      Device.new(name, device_type, ip, channel)
    end

    def parse_cdj_status(
          <<name::binary-size(20), 0x1, _subtype, _device_number, _length::binary-size(2),
            channel, 0x0, 0x0, is_active, _track_loaded_on_device, _track_loaded_on_slot,
            _track_type, 0x0, rekordbox::binary-size(4), rest::binary>>
        ) do
      IO.inspect(rest)
      %{is_active: is_active, channel: channel, rekordbox: rekordbox}
    end

    def create_keep_alive(iface, device_name, channel) do
      mac = iface |> Iface.hwaddr()
      ip = iface |> Iface.ipv4addr()

      p = @header
      p = [p, <<0x6, 0x0>>]
      p = [p, add_padding(device_name, 0x0, 20)]
      p = [p, <<0x01, 0x02, 0x00, 0x36>>]
      p = [p, :binary.encode_unsigned(channel)]
      p = [p, <<0x01>>]
      p = [p, mac]
      p = [p, ip]
      p = [p, <<0x01, 0x00, 0x00, 0x00, 0x01, 0x00>>]
      p
    end

    defp add_padding(string, pad, size) do
      {string, _} = String.split_at(string, size)
      padding = size - byte_size(string)
      for _x <- 1..padding, into: string, do: <<pad>>
    end
  end

  defmodule VCDJ do
    use GenServer

    def init(state), do: {:ok, state}

    def start_link(state \\ %{}) do
      GenServer.start_link(__MODULE__, state)
    end

    def handle_cast(:send_keep_alives, state) do
      Socket.send(
        state.announcements_socket,
        state.iface |> Iface.broadcast_addr(),
        Socket.port(state.announcements_socket),
        Packet.create_keep_alive(state.iface, state.device_name, state.channel)
      )

      Process.send_after(self(), :send_keep_alives, 1_500)
      {:noreply, state}
    end

    def handle_cast(:read_status, state) do
      packet = Socket.read(state.details_socket)

      Process.send_after(self(), :read_status, 200)

      case Packet.parse(packet) do
        {:cdj_status, status} ->
          new_status =
            Map.put(
              state.devices_status,
              status.channel,
              status
            )

          IO.inspect(new_status)
          {:noreply, %{state | devices_status: new_status}}

        _ ->
          {:noreply, state}
      end
    end

    def handle_info(:send_keep_alives, state) do
      GenServer.cast(self(), :send_keep_alives)
      {:noreply, state}
    end

    def handle_info(:read_status, state) do
      GenServer.cast(self(), :read_status)
      {:noreply, state}
    end

    def connect(pid) do
      GenServer.cast(pid, :send_keep_alives)
      GenServer.cast(pid, :read_status)
    end
  end

  defmodule DeviceFinder do
    use GenServer

    def init(state), do: {:ok, state}

    def start_link(state \\ %{}) do
      GenServer.start_link(__MODULE__, state)
    end

    def handle_info(:start, state) do
      {:noreply, loop(state)}
    end

    def handle_call(:query, _from, state) do
      {:reply, state.devices, state}
    end

    defp loop(%{devices: devices, socket: socket}) do
      packet = Socket.read(socket)

      Process.send_after(self(), :start, 500)

      case Packet.parse(packet) do
        {:keep_alive, device} ->
          new_devices =
            Map.update(
              devices,
              device.ip,
              device,
              &%{&1 | last_received: Time.utc_now()}
            )

          %{devices: new_devices, socket: socket}

        _ ->
          %{devices: devices, socket: socket}
      end
    end

    def start(pid) when is_pid(pid), do: send(pid, :start)
    def query(pid), do: GenServer.call(pid, :query)
  end

  def start() do
    {:ok, announcements_socket} = Socket.start_link(50_000)
    {:ok, sync_channel} = Socket.start_link(50_001)
    {:ok, details_socket} = Socket.start_link(50_002)

    device_finder = %{
      devices: %{},
      socket: announcements_socket
    }

    {:ok, finder_pid} = DeviceFinder.start_link(device_finder)
    DeviceFinder.start(finder_pid)

    vcdj = %{
      device_name: "Hello Seahorse",
      iface: Iface.find('en4'),
      channel: 4,
      devices_status: %{},
      announcements_socket: announcements_socket,
      details_socket: details_socket
    }

    {:ok, cdj} = VCDJ.start_link(vcdj)
    VCDJ.connect(cdj)

    {:ok, finder_pid, cdj}
  end
end
