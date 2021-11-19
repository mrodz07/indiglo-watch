defmodule TimexWeb.StopwatchManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, count: ~T[00:00:00.0000], st: Paused, mode: Time, timer: nil}}
  end

  def handle_info(:"bottom-left", %{mode: SWatch, ui_pid: ui, count: count} = state) do
    GenServer.cast(ui, {:set_time_display, Time.to_string(count) |> String.slice(3..-3)})
    {:noreply, %{state | count: ~T[00:00:00.0000]}}
  end

  def handle_info(:"top-left", %{mode: SWatch} = state) do
    {:noreply, %{state | mode: Time}}
  end

  def handle_info(:"top-left", %{mode: Time, ui_pid: ui, count: count} = state) do
    GenServer.cast(ui, {:set_time_display, Time.to_string(count) |> String.slice(3..-3)})
    {:noreply, %{state | mode: SWatch}}
  end

  def handle_info(:"bottom-right", %{st: Paused, mode: SWatch, timer: timer} = state) do
    if timer != nil, do: Process.cancel_timer(timer)
    {:noreply, %{state | st: Counting, timer: Process.send_after(self(), :tick_counting, 10)}}
  end

  def handle_info(:"bottom-right", %{st: Counting, mode: SWatch, timer: timer} = state) do
    if timer != nil, do: Process.cancel_timer(timer)
    {:noreply, %{state | st: Paused, timer: nil}}
  end

  def handle_info(:tick_counting, %{st: Counting, mode: mode, ui_pid: ui, count: count} = state) do
    count = Time.add(count, 10, :millisecond)
    if mode == SWatch do
      GenServer.cast(ui, {:set_time_display, Time.to_string(count) |> String.slice(3..-5)})
    end
    {:noreply, %{state | st: Counting, count: count, timer: Process.send_after(self(), :tick_counting, 10)}}
  end

  def handle_info(:editing_mode, state) do
    {:noreply, %{state | mode: Editing}}
  end

  def handle_info(:regular_mode, state) do
    {:noreply, %{state | mode: Time, st: Paused}}
  end

  def handle_info(event, state), do: {:noreply, state}

  #def handle_info(:"top-right", state), do: {:noreply, state}
  #def handle_info(:"bottom-left", %{mode: Time} = state), do: {:noreply, state}
  #def handle_info(:"bottom-right", %{mode: Time} = state), do: {:noreply, state}
  #def handle_info(:"bottom-right", %{mode: Editing} = state), do: {:noreply, state}
  #def handle_info(:"bottom-left", %{mode: Editing} = state), do: {:noreply, state}
end
