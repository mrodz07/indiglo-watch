defmodule TimexWeb.IndigloManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, st: IndigloOff, timer: nil}}
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

end
