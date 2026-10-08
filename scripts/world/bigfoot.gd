class_name Bigfoot
extends Node2D
## The big hairy fella in the woods (see BigfootWoods). Walks a list of global
## points at a set speed, facing where it's going, and reports every footfall
## so the woods can stamp a print and play the stomp.
##
## Junk Toy cut-out: shadow, legs, one slab of fur for the body with a shade
## strip, a swinging arm and a round head whose pale face patch is the one
## feature. Once the player has his leg he only has one left and hops. Origin
## on the ground under his feet so he Y-sorts against the car.

signal footfall(at: Vector2, heading: Vector2)
signal waypoint_reached(index: int)
signal finished

const FUR := Color(0.42, 0.3, 0.21)
const FUR_SHADE := Color(0.32, 0.22, 0.15)
const FACE := Color(0.74, 0.62, 0.5)

## Ground covered per footfall.
const STRIDE_LENGTH := 70.0
const HOP_HEIGHT := 18.0
const STEP_BOUNCE := 6.0
## How far he leans into a run, in pixels at the head.
const RUN_LEAN := 22.0
const RUN_SPEED_THRESHOLD := 250.0

var one_legged := false

var _path: PackedVector2Array = PackedVector2Array()
var _next_index := 0
var _speed := 0.0
var _facing := 1.0
var _stride := 0.0
var _moving := false

func walk_along(points: PackedVector2Array, speed: float) -> void:
	_path = points
	_next_index = 0
	_speed = speed

func _process(delta: float) -> void:
	_moving = _next_index < _path.size()
	if _moving:
		_step_toward(_path[_next_index], delta)
	queue_redraw()

func _step_toward(target: Vector2, delta: float) -> void:
	var to_go := target - global_position
	if absf(to_go.x) > 4.0:
		_facing = signf(to_go.x)
	var step := minf(_speed * delta, to_go.length())
	global_position += to_go.normalized() * step
	var previous_stride := _stride
	_stride += step / STRIDE_LENGTH
	if floorf(_stride) != floorf(previous_stride):
		footfall.emit(global_position, to_go.normalized())
	if global_position.distance_to(target) <= 1.0:
		waypoint_reached.emit(_next_index)
		_next_index += 1
		if _next_index >= _path.size():
			finished.emit()

func _draw() -> void:
	var phase := fposmod(_stride, 1.0)
	var bounce := 0.0
	if _moving:
		bounce = -sin(phase * PI) * (HOP_HEIGHT if one_legged else STEP_BOUNCE)
	var lean := RUN_LEAN if _moving and _speed >= RUN_SPEED_THRESHOLD else 0.0
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, 54.0, 10.0), UiPalette.SHADOW)
	draw_set_transform(Vector2(0.0, bounce), 0.0, Vector2(_facing, 1.0))
	var swing := sin(phase * TAU) * 18.0 if _moving and not one_legged else 0.0
	if one_legged:
		draw_colored_polygon(FlatProps.sliver(Vector2(4.0, -66.0), Vector2(4.0, -bounce), 28.0), FUR)
	else:
		draw_colored_polygon(FlatProps.sliver(Vector2(-16.0, -66.0), Vector2(-16.0 - swing, -bounce), 26.0), FUR_SHADE)
		draw_colored_polygon(FlatProps.sliver(Vector2(16.0, -66.0), Vector2(16.0 + swing, -bounce), 26.0), FUR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-46.0 + lean, -168.0), Vector2(42.0 + lean, -178.0), Vector2(48.0, -60.0), Vector2(-38.0, -54.0),
	]), FUR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40.0, -80.0), Vector2(47.0, -84.0), Vector2(48.0, -60.0), Vector2(-38.0, -54.0),
	]), FUR_SHADE)
	var head := Vector2(10.0 + lean * 1.3, -184.0)
	draw_colored_polygon(FlatProps.octagon(head, 28.0, 24.0), FUR)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(8.0, -10.0), head + Vector2(26.0, -8.0), head + Vector2(27.0, 10.0), head + Vector2(10.0, 14.0),
	]), FACE)
	var arm_swing := -swing * 1.5 if _moving else 0.0
	draw_colored_polygon(FlatProps.sliver(Vector2(26.0 + lean, -160.0), Vector2(40.0 + lean * 0.4 + arm_swing, -50.0), 22.0), FUR_SHADE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
