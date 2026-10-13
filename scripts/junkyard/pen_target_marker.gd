class_name PenTargetMarker
extends Node2D
## Points out the one piece in the crane pen's heap the player is after (the
## toy car motor in "Fish It Out"): a flat, pulsing yellow glow over it and a
## chunky arrow bobbing above it, both kept upright however the piece lies.
## Follows `target` until it's gone or `clear()` is called.

const GLOW_COLOR := Color(0.95, 0.75, 0.1, 0.5)
const ARROW_COLOR := Color(0.95, 0.75, 0.1, 1)
const ARROW_SHADE := Color(0.78, 0.6, 0.06, 1)
const GLOW_RADIUS := 62.0
const PULSE_SPEED := 4.0
const PULSE_AMOUNT := 0.12
const ARROW_LIFT := 120.0
const BOB_SPEED := 5.0
const BOB_HEIGHT := 10.0
## Draw above the heap and the claw.
const MARKER_Z := 30

var target: Node2D
var _time := 0.0

func _init(follow: Node2D = null) -> void:
	target = follow
	top_level = true
	z_index = MARKER_Z

func _process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		queue_free()
		return
	_time += delta
	global_position = target.global_position
	queue_redraw()

func clear() -> void:
	queue_free()

func _draw() -> void:
	var pulse := 1.0 + sin(_time * PULSE_SPEED) * PULSE_AMOUNT
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, GLOW_RADIUS * pulse, GLOW_RADIUS * 0.8 * pulse), GLOW_COLOR)
	var tip := Vector2(0.0, -ARROW_LIFT + sin(_time * BOB_SPEED) * BOB_HEIGHT)
	# A fat down-arrow: a stem and a head in one shape, and its right half
	# a tone darker.
	var arrow := PackedVector2Array([tip, tip + Vector2(-26.0, -26.0), tip + Vector2(-11.0, -26.0),
			tip + Vector2(-11.0, -58.0), tip + Vector2(11.0, -58.0), tip + Vector2(11.0, -26.0),
			tip + Vector2(26.0, -26.0)])
	draw_colored_polygon(arrow, ARROW_COLOR)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(11.0, -58.0), tip + Vector2(11.0, -26.0),
			tip + Vector2(26.0, -26.0)]), ARROW_SHADE)
