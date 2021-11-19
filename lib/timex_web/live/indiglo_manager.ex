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

  def handle_info(:"top-right", %{st: IndigloOn} = state) do
    {:noreply, %{state | timer: Process.send_after(self(), :unset_indiglo, 2000)}}
  end

  def handle_info(:unset_indiglo, %{ui_pid: ui, st: IndigloOn} = state) do
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: IndigloOff, timer: nil}}
  end

  def handle_info(:unset_indiglo, %{st: AlarmOn, ui_pid: ui, cnt: 5} = state) do 
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: IndigloOff, timer: nil, cnt: 0}}
  end

  def handle_info(:unset_indiglo, %{ui_pid: ui, st: AlarmOn, cnt: cnt} = state) do
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: AlarmOff, cnt: cnt + 1, timer: Process.send_after(self(), :set_indiglo, 1000)}}
  end

  def handle_info(:set_indiglo, %{ui_pid: ui, cnt: cnt, st: AlarmOff} = state) do
    GenServer.cast(ui, :set_indiglo)
    {:noreply, %{state | st: AlarmOn, cnt: cnt + 1, timer: Process.send_after(self(), :unset_indiglo, 1000)}}
  end

  def handle_info(:start_alarm, %{cnt: cnt, timer: timer, st: st} = state) do 
    {:noreply, %{state | st: AlarmOff, timer: Process.send_after(self(), :set_indiglo, 1000)}}
  end

  def handle_info(event, state), do: {:noreply, state}

  #def handle_info(:regular_mode, state), do: {:noreply, state}
  #def handle_info(:editing_mode, state), do: {:noreply, state}
  #def handle_info(:"top-left", state), do: {:noreply, state}
  #def handle_info(:"bottom-left", state), do: {:noreply, state}
  #def handle_info(:"bottom-right", state), do: {:noreply, state}
end
