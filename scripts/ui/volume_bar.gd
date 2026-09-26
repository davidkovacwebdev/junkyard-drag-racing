@tool
class_name VolumeBar
extends Control
## Volume picker: a row of blocks growing taller left to right, filled yellow
## up to the level. Click or drag to set it, or focus it and use left/right.
## Greys out while `muted` so the level stays visible but reads as off.

signal value_changed(value: float)

const BLOCK_COUNT := 10
const BLOCK_GAP := 4.0
const MIN_BLOCK_HEIGHT := 0.35
## Per-block height wobble, so the row looks hand-cut.
const HEIGHT_JITTER := [0.0, -2.0, 1.0, -1.0, 2.0, 0.0, -2.0, 1.0, -1.0, 1.0]

## 0..1, snapped to whole blocks.
@export_range(0.0, 1.0) var value: float = 1.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0)
		queue_redraw()
@export var muted: bool = false:
	set(new_value):
		muted = new_value
		queue_redraw()

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_set_from_mouse(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_set_from_mouse(event.position.x)
		accept_event()
	elif event.is_action_pressed("ui_left"):
		_set_block_count(filled_blocks() - 1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_set_block_count(filled_blocks() + 1)
		accept_event()

func filled_blocks() -> int:
	return roundi(value * BLOCK_COUNT)

## Clicking left of the first block turns it all the way down.
func _set_from_mouse(x: float) -> void:
	var block_width := _block_width()
	_set_block_count(clampi(ceili(x / (block_width + BLOCK_GAP)), 0, BLOCK_COUNT))

func _set_block_count(count: int) -> void:
	count = clampi(count, 0, BLOCK_COUNT)
	if count == filled_blocks():
		return
	value = float(count) / BLOCK_COUNT
	value_changed.emit(value)

func _block_width() -> float:
	return (size.x - BLOCK_GAP * (BLOCK_COUNT - 1)) / BLOCK_COUNT

func _draw() -> void:
	var block_width := _block_width()
	var lit := has_focus() or get_global_rect().has_point(get_global_mouse_position())
	var fill_color := UiPalette.POST_GREY if muted else UiPalette.ACCENT_YELLOW
	var empty_color := UiPalette.STAT_EMPTY.lightened(0.08) if lit else UiPalette.STAT_EMPTY
	for i in BLOCK_COUNT:
		var growth := lerpf(MIN_BLOCK_HEIGHT, 1.0, float(i) / (BLOCK_COUNT - 1))
		var height: float = clampf(size.y * growth + HEIGHT_JITTER[i], 4.0, size.y)
		var left := i * (block_width + BLOCK_GAP)
		var color := fill_color if i < filled_blocks() else empty_color
		draw_rect(Rect2(left, size.y - height, block_width, height), color)
