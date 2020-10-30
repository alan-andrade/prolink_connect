defmodule Prolink.Env do
  use GenServer

  @hello 50_000
  @status 50_002

  def start_link(_) do
    GenServer.start_link(__MODULE__, :noop, name: __MODULE__)
  end

  def init(_) do
    {:ok,
     [
       announcements_port(),
       status_port()
     ]}
  end

  defp announcements_port() do
    {:ok, socket} =
      :gen_udp.open(@hello, [
        :binary,
        {:broadcast, true},
        {:dontroute, true}
      ])

    {:announcements, @hello, socket}
  end

  defp status_port() do
    {:ok, socket} = :gen_udp.open(@status, [:binary])
    {:status, @status, socket}
  end
end
