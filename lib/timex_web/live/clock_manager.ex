defmodule TimexWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    Process.send_after(self(), :working, 1000)
    Process.send_after(self(), :watching_mode, 1000)
    {:ok, %{ui_pid: ui, mode: Time, time: Time.from_erl!(now), alarm: ~T[00:00:00.00], timer: nil, selection: nil, show: nil, count: 0}}
  end

  def handle_info(:"top-left", %{mode: Time} = state), do: {:noreply, %{state | mode: SWatch}}

  def handle_info(:"top-left", %{ui_pid: ui, mode: SWatch} = state), do: {:noreply, %{state | mode: Time}}

  def handle_info(:working, %{ui_pid: ui, mode: Time, time: time, timer: timer} = state) do
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string})
    {:noreply, %{state | time: Time.add(time, 1), timer: Process.send_after(self(), :working, 1000)}}
  end

  def handle_info(:working, %{mode: mode, time: time} = state), do: {:noreply, %{state | time: Time.add(time, 1), timer: Process.send_after(self(), :working, 1000)}}

  def handle_info(:"bottom-right", %{ui_pid: ui, mode: Time, timer: timer} = state) do 
    Process.cancel_timer(timer)
    {:noreply, %{state | mode: TEditing, selection: Hour, show: true, timer: Process.send_after(self(), :time_editing_mode, 250)}}
  end

  def handle_info(:"bottom-right", %{ui_pid: ui, mode: TEditing, timer: timer, selection: nil, show: nil, count: 0} = state) do 
    Process.cancel_timer(timer)
    {:noreply, %{state | mode: Time, timer: Process.send_after(self(), :working, 250)}} 
  end

  def handle_info(:"bottom-left", %{ui_pid: ui, mode: Time, timer: timer} = state) do 
    Process.cancel_timer(timer)
    {:noreply, %{state | mode: AEditing, selection: Hour, show: true, timer: Process.send_after(self(), :alarm_editing_mode, 250)}}
  end

  def handle_info(:"bottom-left", %{ui_pid: ui, mode: AEditing, timer: timer, selection: nil, show: nil, count: 0} = state) do 
    Process.cancel_timer(timer)
    {:noreply, %{state | mode: Time, timer: Process.send_after(self(), :working, 250)}} 
  end

  #def handle_info(:time_editing_mode, %{ui_pid: ui, mode: TEditing, count: 0, timer: timer} = state) do 
  #  GenServer.cast(ui, :editing_mode)
  #  {:noreply, %{state | timer: Process.send_after(self(), :time_editing_mode, 250)}} 
  #end

  def handle_info(:time_editing_mode, %{ui_pid: ui, mode: TEditing, time: time, selection: sel, show: shw, count: 20, timer: timer} = state) do 
    GenServer.cast(ui, :regular_mode)
    {:noreply, %{state | mode: Time, count: 0, selection: nil, show: nil, timer: Process.send_after(self(), :working, 250)}}
  end

  def handle_info(:time_editing_mode, %{ui_pid: ui, mode: TEditing, time: time, selection: sel, show: shw, count: count, timer: timer} = state) do
      GenServer.cast(ui, {:set_time_display, format(%{time: time, selection: sel, show: shw})})
      {:noreply, %{state | count: count + 1, show: !shw, timer: Process.send_after(self(), :time_editing_mode, 250)}}
  end

  def handle_info(:"bottom-right", %{ui_pid: ui, mode: TEditing, time: time, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: time, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, selection: change_selection(sel)}}
  end

  def handle_info(:"bottom-left", %{ui_pid: ui, mode: TEditing, time: time, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: time, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, time: increase_selection(time, sel)}}
  end

  def handle_info(:alarm_editing_mode, %{ui_pid: ui, mode: AEditing, alarm: alarm, selection: sel, show: shw, count: 20, timer: timer} = state), do: {:noreply, %{state | mode: Time, count: 0, selection: nil, show: nil, timer: Process.send_after(self(), :working, 250)}}

  def handle_info(:alarm_editing_mode, %{ui_pid: ui, mode: AEditing, alarm: alarm, selection: sel, show: shw, count: count, timer: timer} = state) do
      GenServer.cast(ui, {:set_time_display, format(%{time: alarm, selection: sel, show: shw})})
      {:noreply, %{state | count: count + 1, show: !shw, timer: Process.send_after(self(), :alarm_editing_mode, 250)}}
  end

  def handle_info(:"bottom-right", %{ui_pid: ui, mode: AEditing, alarm: alarm, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: alarm, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, selection: change_selection(sel)}}
  end

  def handle_info(:"bottom-left", %{ui_pid: ui, mode: AEditing, alarm: alarm, selection: sel, count: count, show: show} = state) do
    GenServer.cast(ui, {:set_time_display, format(%{time: alarm, selection: sel, show: true})})
    {:noreply, %{state | count: 0, show: true, alarm: increase_selection(alarm, sel)}}
  end

  def handle_info(:watching_mode, %{ui_pid: ui, mode: mode, time: time, alarm: alarm} = state) do
    Process.send_after(self(), :watching_mode, 1000)
    if time == alarm, do: GenServer.cast(ui, :start_alarm)
    {:noreply, state}
  end

  def change_selection(Hour), do: Minute
  def change_selection(Minute), do: Second
  def change_selection(Second), do: Hour

  def increase_selection(time, Hour), do: Time.add(time, 3600)
  def increase_selection(time, Minute), do: Time.add(time, 60)
  def increase_selection(time, Second), do: Time.add(time, 1)

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

  def handle_info(:start_alarm, state), do: {:noreply, state}
  def handle_info(:regular_mode, state), do: {:noreply, state}
  def handle_info(:"top-right", state), do: {:noreply, state}
  def handle_info(:"top-left", %{mode: TEditing} = state), do: {:noreply, state}
  def handle_info(:"top-left", %{mode: AEditing} = state), do: {:noreply, state}
  def handle_info(:"bottom-left", %{mode: SWatch } = state), do: {:noreply, state}
  def handle_info(:"bottom-right", %{mode: SWatch } = state), do: {:noreply, state}
end
