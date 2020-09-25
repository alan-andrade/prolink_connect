defmodule ProlinkConnect do
  use GenServer

  defmodule Socket do
    def open(port) do
      :gen_udp.open(port, [:binary, {:broadcast, true}, {:dontroute, true}, {:active, false}])
    end

    def send(socket, host, port, packet) do
      :gen_udp.send(socket, host, port, packet)
    end

    def read(socket) do
      case :gen_udp.recv(socket, 5, 1_500) do
        {:ok, {_, _, packet}} -> packet
        _ -> <<>>
      end
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
      found = interfaces |> Enum.filter(&(elem(&1, 0) |> to_string == name))

      case found do
        [iface] -> {:ok, iface}
        [] -> {:error, "No interface found with name #{name}"}
      end
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
            channel, 0x0, 0x0, _activity, _track_loaded_on_device, _track_loaded_on_slot,
            _track_type, 0x0, rekordbox::binary-size(4), _gargabe::binary-size(87), status,
            rest::binary>>
        ) do
      %{status: status, channel: channel, rekordbox: rekordbox}
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

  @impl true
  def init(env) do
    {:ok, env}
  end

  def start_link(opts \\ [iface: "en4", vcdj_name: "VCDJ-V0.1", vcdj_channel: 4]) do
    {:ok, announcements_socket} = Socket.open(50_000)
    {:ok, sync_socket} = Socket.open(50_001)
    {:ok, details_socket} = Socket.open(50_002)
    {:ok, iface} = Keyword.fetch!(opts, :iface) |> Iface.find()

    state = %{
      announcements_socket: announcements_socket,
      sync_socket: sync_socket,
      details_socket: details_socket,
      devices: %{},
      status: %{},
      iface: iface,
      vcdj: %{
        name: Keyword.fetch!(opts, :vcdj_name),
        channel: Keyword.fetch!(opts, :vcdj_channel)
      }
    }

    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def handle_call(:query, _from, state) do
    {:reply, state.status, state}
  end

  def handle_call(:watch, _from, state) do
    {:ok, {:interval, watcher}} = :timer.send_interval(1_500, __MODULE__, :watch)
    new_state = Map.put(state, :watcher, watcher)
    {:reply, watcher, new_state}
  end

  def handle_info(:watch, state) do
    packet = Socket.read(state.announcements_socket)
    devices = Map.fetch!(state, :devices)

    case Packet.parse(packet) do
      {:keep_alive, device} ->
        new_devices =
          Map.update(
            devices,
            device.channel,
            device,
            &%{&1 | last_received: Time.utc_now()}
          )

        {:noreply, %{state | devices: new_devices}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_call(:connect, _from, state) do
    {:ok, {:interval, keep_alives}} = :timer.send_interval(1_500, __MODULE__, :send_keep_alives)
    {:ok, {:interval, status_reads}} = :timer.send_interval(200, __MODULE__, :read_status)
    new_state = Map.put(state, :keep_alives, keep_alives)
    new_state = Map.put(new_state, :status_reads, status_reads)
    {:reply, :ok, new_state}
  end

  def handle_call(:stop, _from, state) do
    state.watcher |> :timer.cancel()
    {:reply, state, state}
  end

  def handle_info(:send_keep_alives, state) do
    Socket.send(
      state.announcements_socket,
      state.iface |> Iface.broadcast_addr(),
      50_000,
      Packet.create_keep_alive(state.iface, state.vcdj.name, state.vcdj.channel)
    )

    {:noreply, state}
  end

  def handle_info(:read_status, state) do
    packet = Socket.read(state.details_socket)

    case Packet.parse(packet) do
      {:cdj_status, status} ->
        new_status =
          Map.put(
            state.status,
            status.channel,
            status
          )

        {:noreply, %{state | status: new_status}}

      _ ->
        {:noreply, state}
    end
  end

  def query() do
    GenServer.call(__MODULE__, :query)
  end

  def watch() do
    GenServer.call(__MODULE__, :watch)
  end

  def connect() do
    GenServer.call(__MODULE__, :connect)
  end

  def stop() do
    GenServer.call(__MODULE__, :stop)
  end
end
