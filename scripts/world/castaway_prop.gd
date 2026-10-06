@tool
class_name CastawayProp
extends StaticBody2D
## One piece of the lonely island off the desert coast: the castaway, a skinny
## bearded man in ragged shorts waving one arm over his head at anyone on the
## shore, or his little driftwood campfire. Flat polygons, origin on the ground
## so it Y-sorts against the palm.

enum Kind { CASTAWAY, CAMPFIRE }

@export var kind: Kind = Kind.CASTAWAY:
	set(value):
		kind = value
		queue_redraw()

const SKIN := Color(0.78, 0.56, 0.4)
const SHORTS := Color(0.3, 0.42, 0.58)
const BEARD := Color(0.74, 0.72, 0.66)
const DRIFTWOOD := Color(0.56, 0.48, 0.4)
const FLAME_OUTER := Color(0.92, 0.46, 0.14)
const FLAME_INNER := UiPalette.ACCENT_YELLOW

const SHOULDER := Vector2(8.0, -74.0)
const ARM_LENGTH := 44.0
const WAVE_SPEED := 1.6
const WAVE_DEGREES := 28.0
const FLICKER_SPEED := 8.0

var _time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36.0, 10.0) if kind == Kind.CASTAWAY else Vector2(56.0, 14.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -shape.size.y * 0.5)
	add_child(collision)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	match kind:
		Kind.CASTAWAY:
			_draw_castaway()
		Kind.CAMPFIRE:
			_draw_campfire()

## Legs, ragged shorts (the jagged hem is his feature), torso, head and a big
## beard. The waving arm swings back and forth over his head.
func _draw_castaway() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 24.0, 6.0), UiPalette.SHADOW)
	draw_rect(Rect2(-10.0, -30.0, 20.0, 30.0), SKIN.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13.0, -50.0), Vector2(13.0, -50.0), Vector2(14.0, -26.0), Vector2(7.0, -32.0),
		Vector2(1.0, -24.0), Vector2(-5.0, -32.0), Vector2(-14.0, -26.0),
	]), SHORTS)
	draw_rect(Rect2(-11.0, -80.0, 22.0, 32.0), SKIN)
	var swing := deg_to_rad(sin(_time * TAU * WAVE_SPEED) * WAVE_DEGREES)
	var hand := SHOULDER + Vector2.from_angle(deg_to_rad(-70.0) + swing) * ARM_LENGTH
	draw_colored_polygon(FlatProps.sliver(SHOULDER, hand, 8.0), SKIN)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -94.0), 12.0, 13.0), SKIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12.0, -92.0), Vector2(12.0, -92.0), Vector2(8.0, -70.0), Vector2(0.0, -62.0), Vector2(-8.0, -70.0),
	]), BEARD)

## Two crossed driftwood sticks with a flickering two-tone flame.
func _draw_campfire() -> void:
	draw_colored_polygon(FlatProps.sliver(Vector2(-26.0, -2.0), Vector2(24.0, -12.0), 9.0), DRIFTWOOD)
	draw_colored_polygon(FlatProps.sliver(Vector2(-24.0, -12.0), Vector2(26.0, -2.0), 9.0), DRIFTWOOD.darkened(0.2))
	var flicker := 1.0 + sin(_time * FLICKER_SPEED) * 0.15 + sin(_time * FLICKER_SPEED * 1.7) * 0.1
	draw_colored_polygon(FlatProps.flame(Vector2(0.0, -8.0), 18.0, 44.0 * flicker), FLAME_OUTER)
	draw_colored_polygon(FlatProps.flame(Vector2(0.0, -10.0), 9.0, 24.0 * flicker), FLAME_INNER)
