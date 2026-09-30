@tool
class_name TrunkPanel
extends Control
## The open trunk of the player's car, seen from behind: the lid propped up
## on top, the dark boot space in the middle (where the TrunkSlots sit) and
## the bumper along the bottom. Seven flat shapes, sized from `size`.
##
## Paint is a muted tone-step of the starter car's red, so it reads as the
## same car without a big loud-red surface.

const PAINT := Color(0.48, 0.21, 0.18)
const PAINT_LIGHT := Color(0.55, 0.25, 0.21)
const PAINT_SHADE := Color(0.41, 0.18, 0.15)
const LID_SHADE := Color(0.36, 0.16, 0.13)
const SHADOW_OFFSET := Vector2(10.0, 12.0)

## The boot space as fractions of the panel, so slots can be laid out in it.
const OPENING := Rect2(0.1, 0.3, 0.8, 0.54)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

## The boot space in local pixels.
func opening_rect() -> Rect2:
	return Rect2(OPENING.position * size, OPENING.size * size)

func _draw() -> void:
	var body := _points([
		Vector2(0.03, 0.26), Vector2(0.97, 0.25), Vector2(0.98, 0.9), Vector2(0.02, 0.91),
	])
	_poly(_offset(body, SHADOW_OFFSET), UiPalette.SHADOW)
	_poly(body, PAINT)
	_poly(_points([
		Vector2(0.9, 0.25), Vector2(0.97, 0.25), Vector2(0.98, 0.9), Vector2(0.91, 0.9),
	]), PAINT_SHADE)
	# The lid, propped open: wider at its top edge, leaning back over the boot.
	_poly(_points([
		Vector2(0.04, 0.02), Vector2(0.95, 0.0), Vector2(0.9, 0.24), Vector2(0.09, 0.25),
	]), PAINT_LIGHT)
	_poly(_points([
		Vector2(0.09, 0.2), Vector2(0.9, 0.19), Vector2(0.9, 0.24), Vector2(0.09, 0.25),
	]), LID_SHADE)
	var o := opening_rect()
	_poly(PackedVector2Array([
		o.position, Vector2(o.end.x, o.position.y - 2.0), o.end, Vector2(o.position.x, o.end.y + 2.0),
	]), UiPalette.VOID)
	_poly(_points([
		Vector2(0.0, 0.88), Vector2(1.0, 0.87), Vector2(0.99, 0.99), Vector2(0.01, 1.0),
	]), UiPalette.METAL_GREY)

func _points(fractions: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for f: Vector2 in fractions:
		out.append(f * size)
	return out

func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out

func _poly(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
