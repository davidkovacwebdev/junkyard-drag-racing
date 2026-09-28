class_name CrucibleSlot
extends Control
## One of the scrap forge's crucibles: an iron pot with a part sitting in it,
## glowing once it's full. Click it to take the part back out.

signal pressed

const _PART_ICON_SCENE := preload("res://scenes/garage/part_icon.tscn")
const IRON := Color(0.26, 0.26, 0.28)
const IRON_SHADE := Color(0.2, 0.2, 0.22)
const IRON_LIGHT := Color(0.38, 0.38, 0.4)
const EMBER := Color(0.85, 0.32, 0.08)

var part: PartData = null
var _icon: PartIcon
var _hovering := false

func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = _PART_ICON_SCENE.instantiate()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	mouse_entered.connect(_set_hovering.bind(true))
	mouse_exited.connect(_set_hovering.bind(false))
	_notification(NOTIFICATION_RESIZED)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _icon != null:
		_icon.size = Vector2(72, 72)
		_icon.position = (size - _icon.size) / 2.0 - Vector2(0.0, 6.0)
		queue_redraw()

func set_part(new_part: PartData) -> void:
	part = new_part
	_icon.show_part(part)
	queue_redraw()

## The part icon, for the forge's smash animation to shake about.
func get_icon() -> Control:
	return _icon

func _set_hovering(value: bool) -> void:
	_hovering = value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(10.0, h * 0.25), Vector2(w - 4.0, h * 0.25), Vector2(w - 14.0, h + 4.0), Vector2(20.0, h + 4.0),
	]), UiPalette.SHADOW)
	var pot := PackedVector2Array([
		Vector2(4.0, h * 0.18), Vector2(w - 4.0, h * 0.18), Vector2(w - 16.0, h - 4.0), Vector2(16.0, h - 4.0),
	])
	draw_colored_polygon(pot, IRON_LIGHT if _hovering and part != null else IRON)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w - 22.0, h * 0.18), Vector2(w - 4.0, h * 0.18), Vector2(w - 16.0, h - 4.0), Vector2(w - 30.0, h - 4.0),
	]), IRON_SHADE)
	draw_rect(Rect2(12.0, h * 0.18 + 6.0, w - 24.0, h * 0.55), UiPalette.VOID)
	if part != null:
		draw_rect(Rect2(12.0, h * 0.18 + 6.0 + h * 0.43, w - 24.0, h * 0.12), EMBER)
	draw_rect(Rect2(0.0, h * 0.12, w, 8.0), IRON_SHADE)
	draw_rect(Rect2(6.0, h * 0.12, w * 0.3, 3.0), IRON_LIGHT)
