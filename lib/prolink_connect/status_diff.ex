defmodule ProlinkConnect.StatusDiff do
  def diff(a, b) do
    diff = MapDiff.diff(a, b)

    if get_in(diff, [:added, :track_id]) != nil do
      :new_track
    else
      :noop
    end
  end
end
