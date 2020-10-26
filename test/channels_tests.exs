defmodule ChannelsTest do
  use ExUnit.Case
  alias ProlinkConnect.Channels

  test "Adds a new device on any given channel" do
    device =
      Channels.new()
      |> Channels.add_device(1, %{test: "foo"})
      |> Channels.get_device(1)

    assert(device.test == "foo")
  end

  test "Overwrites when adding a new device" do
    device =
      Channels.new()
      |> Channels.add_device(1, %{name: "original"})
      |> Channels.add_device(1, %{name: "copy"})
      |> Channels.get_device(1)

    assert(device.name == "copy")
  end

  test "Prunes devices 3+ seconds old" do
    device =
      Channels.new()
      |> Channels.add_device(1, %{test: "stale"}, Time.add(Time.utc_now(), -4, :second))
      |> Channels.prune()
      |> Channels.get_device(1)

    assert(device == nil)
  end

  test "Gets all devices" do
    devices =
      Channels.new()
      |> Channels.add_device(1, %{name: "foo"})
      |> Channels.add_device(2, %{name: "bar"})
      |> Channels.all()

    assert(length(devices) == 2)
  end
end
