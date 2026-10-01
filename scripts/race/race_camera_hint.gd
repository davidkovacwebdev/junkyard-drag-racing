class_name RaceCameraHint
extends Control
## Small board in the race's bottom-left corner: what the camera is doing
## now, and the keys for taking it over (see CameraFollow).

const CONTROLS_TEXT := "Wheel: Zoom   Drag / WASD: Look   Tab: Next Car   R: Reset"
const BOARD_SIZE := Vector2(470, 58)
const MARGIN := 16.0

var _status_label := Label.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = MARGIN
	offset_right = MARGIN + BOARD_SIZE.x
	offset_top = -MARGIN - BOARD_SIZE.y
	offset_bottom = -MARGIN
	var board := ScrapPanel.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.nails = false
	board.tilt_degrees = 1.0
	board.jitter_seed = 77
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	var lines := VBoxContainer.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	add_child(lines)
	_status_label.add_theme_color_override("font_color", UiPalette.ACCENT_YELLOW)
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_status_label)
	var controls_label := Label.new()
	controls_label.text = CONTROLS_TEXT
	controls_label.add_theme_color_override("font_color", UiPalette.TEXT_LIGHT)
	controls_label.add_theme_font_size_override("font_size", 13)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(controls_label)

func set_status(text: String) -> void:
	_status_label.text = text
