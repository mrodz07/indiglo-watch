defmodule TimexWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()

    Process.send_after(self(), :working, 1000)
    {:ok, %{ui_pid: ui, time: Time.from_erl!(now)}}
  end

  def handle_info(:working, %{ui_pid: ui, time: time} = state) do
    Process.send_after(self(), :working, 1000)
    time = Time.add(time, 1)
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    {:noreply, state |> Map.put(:time, time) }
  end

  def handle_info(_event, state), do: {:noreply, state}
end
