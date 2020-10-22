defmodule DevicesTest do
  use ExUnit.Case
  alias ProlinkConnect.Devices

  test "Adds a new device on any given channel" do
    device =
      Devices.new()
      |> Devices.add_device(1, %{test: "foo"})
      |> Devices.get_device(1)

    assert(device.test == "foo")
  end

  test "Overwrites when adding a new device" do
    device =
      Devices.new()
      |> Devices.add_device(1, %{name: "original"})
      |> Devices.add_device(1, %{name: "copy"})
      |> Devices.get_device(1)

    assert(device.name == "copy")
  end

  test "Prunes devices 3+ seconds old" do
    device =
      Devices.new()
      |> Devices.add_device(1, %{test: "stale"}, Time.add(Time.utc_now(), -4, :second))
      |> Devices.prune()
      |> Devices.get_device(1)

    assert(device == nil)
  end

  test "Gets all devices" do
    devices =
      Devices.new()
      |> Devices.add_device(1, %{name: "foo"})
      |> Devices.add_device(2, %{name: "bar"})
      |> Devices.all()

    assert(length(devices) == 2)
  end
end
