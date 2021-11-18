defmodule TimexWeb.IndigloManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, st: IndigloOff, timer: nil, cnt: 0}}
  end

  def handle_info(:"top-right", %{st: IndigloOff, ui_pid: ui} = state) do
    GenServer.cast(ui, :set_indiglo)
    {:noreply, %{state | st: IndigloOn}}
  end

  def handle_info(:"top-right", %{st: IndigloOn, ui_pid: ui} = state) do
    {:noreply, %{state | st: Waiting, timer: Process.send_after(self(), :"wait-for", 2000)}}
  end

  def handle_info(:"wait-for", %{ui_pid: ui, st: Waiting} = state) do
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: IndigloOff, timer: nil}}
  end

  def handle_info(:start_alarm, %{ui_pid: ui, cnt: cnt, timer: timer} = state) do
    GenServer.cast(ui, :set_indiglo)
    timer = Process.send_after(self(), :AlarmOnToOff, 1000)
    {:noreply, %{state | st: AlarmOn, cnt: cnt, timer: timer}}
  end

  def handle_info(:AlarmOnToOff, %{ui_pid: ui, st: AlarmOn, timer: timer, cnt: cnt} = state) do
    GenServer.cast(ui, :unset_indiglo)
    if(cnt < 5) do
      timer = Process.send_after(self(), :AlarmOffToOn, 1000)
    else
      Process.cancel_timer(timer)
    end
    {:noreply, %{state | st: AlarmOff, timer: timer, cnt: cnt + 1}}
  end

  def handle_info(:AlarmOffToOn, %{ui_pid: ui, st: AlarmOff, cnt: cnt, timer: timer} = state) do
    timer = Process.send_after(self(), :AlarmOnToOff, 1000)
    GenServer.cast(ui, :set_indiglo)
    {:noreply, %{state | st: AlarmOn, timer: timer, cnt: cnt + 1}}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
