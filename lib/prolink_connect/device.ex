defmodule ProlinkConnect.Device do
  defstruct [:name, :ip, :device_type, :channel, :last_received]

  def new(%{name: name, ip: ip, device_type: type, channel: channel}) do
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

defmodule ProlinkConnect.DeviceStatus do
  defstruct [:status, :channel, :rekordbox, :isMaster]

  def new(%{status: status, channel: channel, rekordbox: rekordbox, isMaster: isMaster}) do
    %__MODULE__{
      status: status,
      channel: channel,
      rekordbox: rekordbox,
      isMaster: isMaster
    }
  end
end
