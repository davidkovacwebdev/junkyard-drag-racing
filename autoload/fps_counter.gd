extends CanvasLayer
## Frames-per-second and draw-call readout in the top-right corner. F3 toggles
## it from any scene, paused or not.

const _TOGGLE_KEY := KEY_F3
const _SCREEN_MARGIN := 12.0
const _REFRESH_INTERVAL := 0.25

var _label: Label
var _time_since_refresh := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	visible = false
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -_SCREEN_MARGIN
	_label.offset_top = _SCREEN_MARGIN
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override(&"font_size", 18)
	_label.add_theme_color_override(&"font_color", UiPalette.ACCENT_YELLOW)
	_label.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	_label.add_theme_constant_override(&"outline_size", 6)
	add_child(_label)

func _process(delta: float) -> void:
	if not visible:
		return
	_time_since_refresh += delta
	if _time_since_refresh < _REFRESH_INTERVAL:
		return
	_time_since_refresh = 0.0
	_refresh_text()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == _TOGGLE_KEY:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_text()
	Sfx.play(&"ui_click", Sfx.UI_CLICK_VOLUME_DB)

func _refresh_text() -> void:
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_label.text = "%d FPS\n%d draws" % [Engine.get_frames_per_second(), draw_calls]
