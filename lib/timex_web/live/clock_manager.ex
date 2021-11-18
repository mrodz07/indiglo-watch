defmodule TimexWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()

    Process.send_after(self(), :working, 1000)
    Process.send_after(self(), :watching_mode, 1000)
    {:ok, %{ui_pid: ui, mode: Time, time: Time.from_erl!(now), alarm: alarm = Time.add(Time.from_erl!(now),  60)}}
  end
  def handle_info(:"top-left", %{mode: Time} = state) do
    {:noreply, %{state | mode: SWatch}}
  end
  def handle_info(:"top-left", %{mode: SWatch, ui_pid: ui, time: time} = state) do
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    {:noreply, %{state | mode: Time}}
  end

  def handle_info(:working, %{ui_pid: ui, mode: mode, time: time} = state) do
    Process.send_after(self(), :working, 1000)
    time = Time.add(time, 1)
    if mode == Time do
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    end
    {:noreply, state |> Map.put(:time, time) }
  end

  def handle_info(:watching_mode, %{ui_pid: ui, mode: mode, time: time, alarm: alarm} = state) do
    Process.send_after(self(), :watching_mode, 1000)
    time = Time.add(time, 1)
    if time == alarm do
      GenServer.cast(ui, :start_alarm)
    end
    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
