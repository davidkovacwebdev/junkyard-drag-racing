class_name ChestTopView
extends CanvasLayer
## The treasure chest seen from straight above, filling the screen, for
## ChestOpeningCutscene: the lid swings up on its hinge along the top edge
## (with a creak), and inside, the big boat engine (Treasure Boat Engine,
## its propeller and gold cowl) lies in a bed of gold nuggets. Sits under the
## cutscene layer, so the letterbox bars and subtitles stay on top.

const LAYER := 49
const GROUND := Color(0.34, 0.29, 0.22, 1)
const WOOD := Color(0.5, 0.32, 0.17, 1)
const WOOD_SHADE := Color(0.4, 0.25, 0.13, 1)
const INSIDE := Color(0.16, 0.11, 0.07, 1)
const LATCH := Color(0.9, 0.72, 0.2, 1)
const GOLD := Color(0.9, 0.72, 0.2, 1)
const GOLD_SHADE := Color(0.75, 0.58, 0.14, 1)
const HOUSING := Color(0.25, 0.38, 0.4, 1)
const COWL := Color(0.85, 0.65, 0.2, 1)
const PROPELLER := Color(0.72, 0.5, 0.22, 1)
## The chest's size on screen, and the wooden rim inside it.
const CHEST := Vector2(560.0, 360.0)
const RIM := 28.0
const OPEN_TIME := 1.0

var _view: Control
var _open := 0.0

func _ready() -> void:
	layer = LAYER
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	add_child(_view)

## Swings the lid open. Await it.
func open() -> void:
	Sfx.play(&"cemetery_gate_creak", -6.0, 0.0)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float) -> void:
		_open = t
		_view.queue_redraw(), 0.0, 1.0, OPEN_TIME)
	await tween.finished
	Sfx.play(&"wink_ting", -2.0, 0.0)

func _draw_view() -> void:
	var screen := _view.size
	_view.draw_rect(Rect2(Vector2.ZERO, screen), GROUND)
	var box := Rect2(screen * 0.5 - CHEST * 0.5, CHEST)
	_view.draw_colored_polygon(FlatProps.octagon(box.get_center() + Vector2(14.0, 18.0), CHEST.x * 0.56, CHEST.y * 0.58), UiPalette.SHADOW)
	_view.draw_rect(box, WOOD)
	_view.draw_rect(Rect2(box.position + Vector2(0.0, box.size.y - 16.0), Vector2(box.size.x, 16.0)), WOOD_SHADE)
	var inner := box.grow(-RIM)
	_view.draw_rect(inner, INSIDE)
	_draw_treasure(inner)
	# The lid, hinged along the top: seen from above, it shrinks up to the
	# hinge as it swings open.
	var lid_height := inner.size.y * (1.0 - _open)
	if lid_height > 1.0:
		var lid := Rect2(inner.position - Vector2(RIM * 0.5, RIM * 0.5), Vector2(inner.size.x + RIM, lid_height + RIM * 0.5))
		_view.draw_rect(lid, WOOD)
		_view.draw_rect(Rect2(lid.position + Vector2(0.0, lid.size.y - 14.0), Vector2(lid.size.x, 14.0)), WOOD_SHADE)
		var latch := Vector2(lid.get_center().x, lid.end.y - 6.0)
		_view.draw_rect(Rect2(latch - Vector2(16.0, 18.0), Vector2(32.0, 30.0)), LATCH)

## The boat engine across the middle and gold nuggets heaped round it.
func _draw_treasure(inner: Rect2) -> void:
	var c := inner.get_center()
	var nuggets := [
		[Vector2(-200.0, -90.0), 34.0], [Vector2(-150.0, 80.0), 40.0], [Vector2(170.0, -100.0), 36.0],
		[Vector2(200.0, 70.0), 44.0], [Vector2(-40.0, 110.0), 30.0], [Vector2(60.0, -118.0), 28.0],
	]
	for i in nuggets.size():
		var at: Vector2 = c + nuggets[i][0]
		var r: float = nuggets[i][1]
		var lump := PackedVector2Array([at + Vector2(-r, -r * 0.2), at + Vector2(-r * 0.4, -r * 0.8),
				at + Vector2(r * 0.5, -r * 0.7), at + Vector2(r, 0.0), at + Vector2(r * 0.4, r * 0.7),
				at + Vector2(-r * 0.6, r * 0.6)])
		_view.draw_colored_polygon(lump, GOLD if i % 2 == 0 else GOLD_SHADE)
	# The engine, lying on its side: housing, gold cowl, the leg and the prop.
	_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-130.0, -46.0), c + Vector2(40.0, -50.0),
			c + Vector2(48.0, 50.0), c + Vector2(-130.0, 46.0)]), HOUSING)
	_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-150.0, -40.0), c + Vector2(-126.0, -46.0),
			c + Vector2(-126.0, 46.0), c + Vector2(-150.0, 40.0)]), COWL)
	_view.draw_colored_polygon(FlatProps.sliver(c + Vector2(44.0, 0.0), c + Vector2(130.0, 0.0), 26.0), HOUSING)
	var hub := c + Vector2(134.0, 0.0)
	_view.draw_colored_polygon(PackedVector2Array([hub + Vector2(-8.0, -70.0), hub + Vector2(10.0, -66.0),
			hub + Vector2(8.0, 70.0), hub + Vector2(-10.0, 66.0)]), PROPELLER)
	_view.draw_colored_polygon(PackedVector2Array([hub + Vector2(-46.0, -46.0), hub + Vector2(46.0, 40.0),
			hub + Vector2(40.0, 48.0), hub + Vector2(-48.0, -38.0)]), PROPELLER)
