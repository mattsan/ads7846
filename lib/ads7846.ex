defmodule ADS7846 do
  use GenServer

  @device_name "ADS7846 Touchscreen"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{device_name: @device_name, client: self()})
  end

  def init(opts) do
    device_name = opts[:device_name]

    {path, _info} =
      InputEvent.enumerate()
      |> Enum.find(fn {_path, %InputEvent.Info{name: name}} ->
        name =~ device_name
      end)

    InputEvent.start_link(path)

    {:ok, %{client: opts.client, path: path, button: :release, x: 0, y: 0}}
  end

  def handle_info({:input_event, path, events}, %{path: path} = state) do
    next_state =
      events
      |> Enum.reduce(state, fn
        {:ev_key, :btn_touch, 0}, state -> %{state | button: :release}
        {:ev_key, :btn_touch, 1}, state -> %{state | button: :press}
        {:ev_abs, :abs_x, x}, state -> %{state | x: x}
        {:ev_abs, :abs_y, y}, state -> %{state | y: y}
        _, state -> state
      end)

    input_event =
      case next_state do
        %{button: button, x: x, y: y} when button == state.button ->
          {:cursor_pos, {x, y}}

        %{button: button, x: x, y: y} ->
          {:cursor_button, {:left, button, 0, {x, y}}}

        _ ->
          nil
      end

    if is_tuple(input_event), do: send(next_state.client, {:touch_event, self(), input_event})

    {:noreply, next_state}
  end
end
