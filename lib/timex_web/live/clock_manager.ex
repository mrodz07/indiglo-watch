defmodule TimexWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()

    Process.send_after(self(), :working, 1000)
    Process.send_after(self(), :watching_mode, 1000)
    {:ok, %{ui_pid: ui, mode: Time, time: Time.from_erl!(now), alarm: ~T[00:00:00.00], timer: nil, selection: nil, show: nil, count: 0}}
  end
  def handle_info(:"top-left", %{mode: Time} = state) do
    {:noreply, %{state | mode: SWatch}}
  end
  def handle_info(:"top-left", %{mode: SWatch, ui_pid: ui, time: time} = state) do
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    {:noreply, %{state | mode: Time}}
  end

  def handle_info(:working, %{ui_pid: ui, mode: TEditing, time: time} = state) do
    {:noreply, state}
  end

  def handle_info(:working, %{ui_pid: ui, mode: AEditing, time: time} = state) do
    {:noreply, state}
  end

  def handle_info(:working, %{ui_pid: ui, mode: mode, time: time} = state) do
    Process.send_after(self(), :working, 1000)
    time = Time.add(time, 1)
    if mode == Time do 
      GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string })
    end
    {:noreply, state |> Map.put(:time, time) }
  end

  def handle_info(:"bottom-right", %{ui_pid: ui, mode: Time, timer: timer} = state) do
    if timer == nil do
      {:noreply, %{state | timer: Process.send_after(self(), :waiting_to_editingTime, 250)}}
    else
      Process.cancel_timer(timer)
      {:noreply, %{state | timer: nil}}
    end
  end

  def handle_info(:"bottom-left", %{ui_pid: ui, mode: Time, timer: timer} = state) do
    if timer == nil do
      {:noreply, %{state | timer: Process.send_after(self(), :waiting_to_editingAlarm, 250)}}
    else
      Process.cancel_timer(timer)
      {:noreply, %{state | timer: nil}}
    end
  end

  def handle_info(:"bottom-right", %{ui_pid: ui, mode: Time, timer: timer} = state) do
    if timer == nil do
      {:noreply, %{state | timer: Process.send_after(self(), :waiting_to_editingTime, 250)}}
    else
      Process.cancel_timer(timer)
      {:noreply, %{state | timer: nil}}
    end
  end

  def handle_info(:waiting_to_editingTime, %{ui_pid: ui, mode: mode, timer: timer} = state) do
    GenServer.cast(ui, :time_editing_mode)
    {:noreply, %{state | mode: TEditing, selection: Hour, show: true, timer: nil}}
  end

  def handle_info(:waiting_to_editingAlarm, %{ui_pid: ui, mode: mode, timer: timer} = state) do
    GenServer.cast(ui, :alarm_editing_mode)
    {:noreply, %{state | mode: AEditing, selection: Hour, show: true, timer: nil}}
  end

  def handle_info(:time_editing_mode, %{ui_pid: ui, mode: TEditing, time: time, selection: sel, show: shw, count: count} = state) do
    if count < 20 do
      Process.send_after(self(), :time_editing_mode, 250)
      GenServer.cast(ui, {:set_time_display, format(%{time: time, selection: sel, show: shw})})
      {:noreply, %{state | count: count = count + 1, show: !shw}}
    else
      GenServer.cast(ui, :regular_mode)
      Process.send_after(self(), :working, 10)
      {:noreply, %{state | mode: Time, count: 0, show: true}}
    end
  end

  def handle_info(:"bottom-right", %{ui_pid: ui, mode: TEditing, time: time, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: time, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, selection: change_selection(sel)}}
  end

  def handle_info(:"bottom-left", %{ui_pid: ui, mode: TEditing, time: time, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: time, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, time: increase_selection(time, sel)}}
  end

  def handle_info(:alarm_editing_mode, %{ui_pid: ui, mode: AEditing, alarm: alarm, selection: sel, show: shw, count: count} = state) do
    if count < 20 do
      Process.send_after(self(), :alarm_editing_mode, 250)
      GenServer.cast(ui, {:set_time_display, format(%{time: alarm, selection: sel, show: shw})})
      {:noreply, %{state | count: count = count + 1, show: !shw}}
    else
      GenServer.cast(ui, :regular_mode)
      Process.send_after(self(), :working, 10)
      {:noreply, %{state | mode: Time, count: 0, show: true}}
    end
  end
  
  def handle_info(:"bottom-right", %{ui_pid: ui, mode: AEditing, alarm: alarm, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: alarm, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, selection: change_selection(sel)}}
  end

  def handle_info(:"bottom-left", %{ui_pid: ui, mode: AEditing, alarm: alarm, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: alarm, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, alarm: increase_selection(alarm, sel)}}
  end

  def change_selection(Hour), do: Minute
  def change_selection(Minute), do: Second
  def change_selection(Second), do: Hour

  def increase_selection(time, Hour), do: Time.add(time,  3600)
  def increase_selection(time, Minute), do: Time.add(time,  60)
  def increase_selection(time, Second), do: Time.add(time,  1)

  def handle_info(:watching_mode, %{ui_pid: ui, mode: mode, time: time, alarm: alarm} = state) do
    Process.send_after(self(), :watching_mode, 1000)
    if time == alarm do
      GenServer.cast(ui, :start_alarm)
    end
    {:noreply, state}
  end

  def format(%{show: true, time: time, selection: sel} = state), do: Time.truncate(time, :second) |> Time.to_string
  def format(%{show: false, time: time, selection: Hour} = state) do 
    time = Time.truncate(time, :second) |> Time.to_string |> String.slice(2..7)
    "  " <> time 
  end
  def format(%{show: false, time: time, selection: Minute} = state) do 
    time = Time.truncate(time, :second) |> Time.to_string
    hours = String.slice(time, 0..2)
    seconds = String.slice(time, 5..7)
    hours <> "  " <> seconds
  end

  def format(%{show: false, time: time, selection: Second} = state) do 
    time = Time.truncate(time, :second) |> Time.to_string |> String.slice(0..5)
    time <> "  "
  end

  def handle_info(_event, state), do: {:noreply, state}
end
