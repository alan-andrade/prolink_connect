defmodule ProlinkConnect.Details do
  def new(), do: %{}

  def set_status(state, channel, status) do
    state |> Map.put(channel, status)
  end

  def get_status(state, channel) do
    state |> Map.get(channel, %{})
  end
end
