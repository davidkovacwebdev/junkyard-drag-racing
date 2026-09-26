@tool
class_name ScrapButton
extends BaseButton
## A button that's a single scrap slab (see the ui-style skill). Hover or focus
## lightens the slab, flags it with a yellow sliver and gives it a wobble;
## pressing pushes the slab down into its skirt; disabled greys it out. The text
## stays straight while the slab is tilted.
##
## `selected` is for tabs and filters: the slab stays pushed in and flagged, so
## the current choice reads as the one that's been pressed.

const PRESS_DEPTH := 3.0
const WOBBLE_DEGREES := 3.0
const WOBBLE_TIME := 0.45
const DISABLED_ALPHA := 0.6

@export var text: String = "":
	set(value):
		text = value
		queue_redraw()
@export var font_size: int = 26:
	set(value):
		font_size = value
		queue_redraw()
@export_range(-6.0, 6.0) var tilt_degrees: float = 0.0:
	set(value):
		tilt_degrees = value
		queue_redraw()
@export var jitter_seed: int = 0:
	set(value):
		jitter_seed = value
		queue_redraw()
@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _board := ScrapBoard.new()
var _wobble: float = 0.0:
	set(value):
		_wobble = value
		queue_redraw()

func _ready() -> void:
	mouse_entered.connect(_on_hover_started)
	focus_entered.connect(_on_hover_started)
	mouse_exited.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()

func _on_hover_started() -> void:
	queue_redraw()
	if disabled or Engine.is_editor_hint():
		return
	Sfx.play(&"ui_hover", -14.0)
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_wobble = WOBBLE_DEGREES * (1.0 if tilt_degrees <= 0.0 else -1.0)
	tween.tween_property(self, "_wobble", 0.0, WOBBLE_TIME)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		queue_redraw()

func _draw() -> void:
	var mode := get_draw_mode()
	var lit := not disabled and (selected or mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED or has_focus())
	var pressed_down := selected or mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var press_depth := PRESS_DEPTH if pressed_down else 0.0

	_board.jitter_seed = jitter_seed
	_board.tilt_degrees = tilt_degrees + _wobble
	_board.body_color = UiPalette.SURFACE_LIGHT if lit else UiPalette.SURFACE_BASE
	_board.shade_color = UiPalette.SURFACE_SHADE
	_board.skirt_color = UiPalette.SURFACE_DARK
	_board.highlight_color = UiPalette.ACCENT_YELLOW if lit else Color.TRANSPARENT
	if disabled:
		_board.body_color = UiPalette.SURFACE_BASE.lerp(UiPalette.POST_GREY, 0.7)
		_board.shade_color = UiPalette.SURFACE_SHADE.lerp(UiPalette.POST_GREY, 0.7)
		_board.skirt_color = UiPalette.SURFACE_DARK.lerp(UiPalette.POST_GREY, 0.7)
	self_modulate.a = DISABLED_ALPHA if disabled else 1.0
	var rect := Rect2(Vector2.ZERO, size)
	_board.draw(self, rect, press_depth)

	var font := get_theme_default_font()
	var body := ScrapBoard.body_rect(rect, _board.skirt_height, press_depth)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(body.get_center().x - text_size.x / 2.0,
			body.get_center().y + font.get_ascent(font_size) / 2.0 - font.get_descent(font_size) / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiPalette.TEXT_BROWN)
