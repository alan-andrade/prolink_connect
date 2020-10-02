defmodule ProlinkConnect.Iface do
  def find(name) do
    {:ok, interfaces} = :inet.getifaddrs()
    found = interfaces |> Enum.filter(&(elem(&1, 0) |> to_string == name))

    case found do
      [iface] -> {:ok, iface}
      [] -> {:error, "No interface found with name #{name}"}
    end
  end

  def broadcast_addr({_, opts}) do
    opts[:broadaddr]
  end

  def hwaddr({_, opts}) do
    opts[:hwaddr]
    |> Enum.map(&(&1 |> :binary.encode_unsigned()))
    |> Enum.join()
  end

  def ipv4addr({_, opts}) do
    Keyword.get_values(opts, :addr)
    |> List.last()
    |> Tuple.to_list()
    |> Enum.map(&(&1 |> :binary.encode_unsigned()))
    |> Enum.join()
  end
end
