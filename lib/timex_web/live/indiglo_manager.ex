defmodule TimexWeb.IndigloManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, st: IndigloOff, timer: nil, cnt: 0}}
  end

  # Modo normal
  def handle_info(:"top-right", %{st: IndigloOff, timer: nil} = state) do
    {:noreply, %{state | timer: Process.send_after(self(), :indiglo_turn_on, 100)}}
  end

  def handle_info(:"top-right", %{st: IndigloOn, timer: nil} = state) do
    {:noreply, %{state | timer: Process.send_after(self(), :indiglo_turn_off, 2000)}}
  end

  # Las siguientes dos declaraciones son para evitar que el boton se presione indiscriminadamente y se pueda mandar una llamada a :indiglo_turn_on cuando se tiene el st:IndigloOn y viceversa
  def handle_info(:"top-right", %{st: IndigloOn, timer: timer} = state) do
    Process.cancel_timer(timer)
    {:noreply, %{state | timer: nil}}
  end

  def handle_info(:"top-right", %{st: IndigloOff, timer: timer} = state) do
    Process.cancel_timer(timer)
    {:noreply, %{state | timer: nil}}
  end

  def handle_info(:indiglo_turn_off, %{ui_pid: ui, timer: timer, st: IndigloOn} = state) do
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: IndigloOff, timer: nil}}
  end

  def handle_info(:indiglo_turn_on, %{ui_pid: ui, timer: timer ,st: IndigloOff} = state) do
    GenServer.cast(ui, :set_indiglo)
    {:noreply, %{state | st: IndigloOn, timer: nil}}
  end

  # Se apaga el indiglo si se enciende el modo alarma
  def handle_info(:start_alarm, %{ui_pid: ui, cnt: cnt, timer: timer, st: IndigloOn} = state) do 
    if timer, do: Process.cancel_timer(timer)
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: AlarmOff, timer: Process.send_after(self(), :indiglo_turn_on, 1000)}}
  end

  # Modo alarma
  def handle_info(:start_alarm, %{cnt: cnt, timer: timer, st: st} = state) do 
    if timer, do: Process.cancel_timer(timer)
    {:noreply, %{state | st: AlarmOff, timer: Process.send_after(self(), :indiglo_turn_on, 1000)}}
  end

  def handle_info(:indiglo_turn_on, %{ui_pid: ui, cnt: cnt, st: AlarmOff} = state) do
    GenServer.cast(ui, :set_indiglo)
    {:noreply, %{state | st: AlarmOn, cnt: cnt + 1, timer: Process.send_after(self(), :indiglo_turn_off, 1000)}}
  end

  # Acaba alarma si cnt = 5
  def handle_info(:indiglo_turn_off, %{st: AlarmOn, ui_pid: ui, timer: timer, cnt: 5} = state) do 
    if timer, do: Process.cancel_timer(timer)
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: IndigloOff, timer: nil, cnt: 0}}
  end

  def handle_info(:indiglo_turn_off, %{ui_pid: ui, st: AlarmOn, cnt: cnt} = state) do
    GenServer.cast(ui, :unset_indiglo)
    {:noreply, %{state | st: AlarmOff, cnt: cnt + 1, timer: Process.send_after(self(), :indiglo_turn_on, 1000)}}
  end

  # No se hace nada si se 'castea' :regular_mode o :editing_mode ya que tienen que ver con stopwatch_manager. Los demás handles son porque ninguno de esos botones se ocupa en este modo
  def handle_info(:"top-right", %{st: AlarmOff} = state), do: {:noreply, state}
  def handle_info(:"top-right", %{st: AlarmOn} = state), do: {:noreply, state}
  def handle_info(:regular_mode, state), do: {:noreply, state}
  def handle_info(:editing_mode, state), do: {:noreply, state}
  def handle_info(:"top-left", state), do: {:noreply, state}
  def handle_info(:"bottom-left", state), do: {:noreply, state}
  def handle_info(:"bottom-right", state), do: {:noreply, state}
end
