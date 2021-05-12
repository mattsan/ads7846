defmodule ADS7846 do
  use GenServer

  @name "ADS7846 Touchscreen"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{client: self()})
  end

  def init(opts) do
    {path, info} =
      InputEvent.enumerate()
      |> Enum.find(fn {_path, %InputEvent.Info{name: name}} -> name =~ @name end)

    InputEvent.start_link(path)

    {:ok, %{client: opts.client, path: path, button: :release, x: 0, y: 0}}
  end

  def handle_info({:input_event, path, events}, %{path: path} = state) do
    events
    |> Enum.reduce(%{button: state.button, x: state.x, y: state.y}, fn
      {:ev_key, :btn_touch, 0}, acc -> %{acc | button: :release}
      {:ev_key, :btn_touch, 1}, acc -> %{acc | button: :press}
      {:ev_abs, :abs_x, x}, acc -> %{acc | x: x}
      {:ev_abs, :abs_y, y}, acc -> %{acc | y: y}
      _, acc -> acc
    end)
    |> case do
      %{button: button, x: x, y: y} when button == state.button ->
        send(state.client, {:touch_event, self(), {:cursor_pos, {x, y}}})

        {:noreply, %{state | x: x, y: y}}

      %{button: button, x: x, y: y} ->
        send(state.client, {:touch_event, self(), {:cursor_button, {:left, button, 0, {x, y}}}})

        {:noreply, %{state | button: button, x: x, y: y}}

      _ ->
        {:noreply, state}
    end
  end
end
