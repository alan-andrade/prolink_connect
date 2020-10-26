defmodule ProlinkConnect.Packet do
  require Logger

  alias ProlinkConnect.Iface

  @header <<0x51, 0x73, 0x70, 0x74, 0x31, 0x57, 0x6D, 0x4A, 0x4F, 0x4C>>

  @keep_alive [
    {:name, :parse_string, [0x0C, 20]},
    {:channel, :parse_int, 0x24},
    {:device_type, :parse_int, 0x25},
    {:ip, :parse_ip, [0x2C, 4]}
  ]

  @cdj_status [
    {:channel, :parse_int, 0x21},
    # 228, 164
    {:status, :parse_int, 0x89},
    {:is_master, :parse_int, 0x9E},
    {:slot, :parse_int, 0x29},
    {:track_id, :parse_list, [0x2C, 4]}
  ]

  @parsing_rules %{
    0x06 => @keep_alive,
    0x0A => @cdj_status
  }

  def parse(packet) do
    with {:ok, type} <- get_packet_type(packet),
         {:ok, rules} <- get_parsing_rules(type) do
      {:ok, parse_packet_with_rules(rules, packet)}
    else
      :error -> {:error, :no_packet_rule}
      {:error, error} -> {:error, error}
    end
  end

  defp get_rule_name(rule), do: elem(rule, 0)
  defp get_rule_method(rule), do: elem(rule, 1)
  defp get_rule_position(rule), do: List.flatten([elem(rule, 2)])

  defp get_parsing_rules(packet_type) when is_number(packet_type) do
    Map.fetch(@parsing_rules, packet_type)
  end

  defp get_parsing_rules(_), do: {:error, "packet type not supported"}
  defp get_packet_type(<<@header, packet_type, _rest::binary>>), do: {:ok, packet_type}
  defp get_packet_type(_), do: {:error, "Unkown type"}

  defp parse_packet_with_rules(rules, packet) when is_binary(packet) do
    Enum.reduce(
      rules,
      %{},
      fn rule, acc ->
        key = get_rule_name(rule)
        method = get_rule_method(rule)
        position = get_rule_position(rule)

        data = apply(__MODULE__, method, [packet | position])
        Map.put(acc, key, data)
      end
    )
  end

  def parse_string(packet, position, length) do
    parse_list(packet, position, length)
    |> Enum.filter(&(&1 != 0))
    |> to_string
  end

  def parse_int(packet, position) do
    :binary.at(packet, position)
  end

  def parse_ip(packet, position, length) do
    parse_list(packet, position, length)
    |> :erlang.list_to_tuple()
  end

  def parse_list(packet, position, length), do: :binary.bin_to_list(packet, {position, length})

  def create_keep_alive(iface, device_name, channel) do
    address = iface |> Iface.broadcast_addr()
    mac = iface |> Iface.hwaddr()
    ip = iface |> Iface.ipv4addr()

    p = @header
    p = [p, <<0x6, 0x0>>]
    p = [p, String.pad_trailing(device_name, 20, <<0x0>>)]
    p = [p, <<0x01, 0x02, 0x00, 0x36>>]
    p = [p, :binary.encode_unsigned(channel)]
    p = [p, <<0x01>>]
    p = [p, mac]
    p = [p, ip]
    p = [p, <<0x01, 0x00, 0x00, 0x00, 0x01, 0x00>>]
    {address, p}
  end

  def diff(old, new) when is_map(old) and is_map(new) do
    Map.keys(new)
    |> Enum.reduce(%{}, fn key, acc ->
      old_value = Map.get(old, key)
      new_value = Map.get(new, key)

      if new_value !== old_value do
        Map.merge(acc, %{key => new_value})
      else
        acc
      end
    end)
  end

  def diff(_, _), do: %{}
end
