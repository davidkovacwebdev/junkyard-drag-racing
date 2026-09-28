class_name Shark
extends Node2D
## One shark cruising the ocean seen from above: a dark silhouette under the
## surface, the fin cutting through it and a wake trailing behind. Surfaces
## with a splash, wanders around, turns away from land and dives again.
## Spawned and kept in open water by SharkSpawner.

## Opaque, pre-mixed with the deep water colour, so overlapping pieces
## don't show darker seams the way translucent ones would.
const BODY_COLOR := Color(0.14, 0.33, 0.44)
const FIN_COLOR := Color("56646e")
const FIN_SHADE_COLOR := Color("3d4950")
const WAKE_COLOR := Color(0.9, 0.97, 1.0, 0.45)
const FADE_TIME := 1.2
const LOOK_AHEAD := 260.0
const TURN_RATE := 1.4
const TAIL_SWING := 0.35
const SPLASH_DB := -10.0
## Shore checks are a handful of point-in-polygon tests, so only redone a few
## times a second.
const STEER_CHECK_INTERVAL := 0.25

var speed: float = 80.0
var lifetime: float = 20.0
## Returns true where the shark must not go (land or too close to shore).
var is_blocked: Callable

var _heading: float = 0.0
var _age: float = 0.0
var _wander_phase: float = 0.0
var _tail: Polygon2D
var _wake: Node2D
var _diving := false
var _steer_check_timer: float = 0.0
var _avoid_turn: float = 0.0

func _ready() -> void:
	_wander_phase = randf() * TAU
	_heading = rotation
	_build_art()
	modulate.a = 0.0
	Sfx.play_at(&"shark_splash", global_position, SPLASH_DB)

func _process(delta: float) -> void:
	_age += delta
	if not _diving and _age >= lifetime:
		dive()
	if _diving:
		modulate.a = maxf(0.0, modulate.a - delta / FADE_TIME)
		if modulate.a <= 0.0:
			queue_free()
			return
	else:
		modulate.a = minf(1.0, modulate.a + delta / FADE_TIME)

	_steer(delta)
	position += Vector2.from_angle(_heading) * speed * delta
	rotation = _heading
	_tail.rotation = sin(_age * 5.0) * TAIL_SWING
	_wake.modulate.a = 0.75 + 0.25 * sin(_age * 7.0)

func dive() -> void:
	if _diving:
		return
	_diving = true
	Sfx.play_at(&"shark_splash", global_position, SPLASH_DB - 3.0)

func _steer(delta: float) -> void:
	_steer_check_timer -= delta
	if _steer_check_timer <= 0.0 and is_blocked.is_valid():
		_steer_check_timer = STEER_CHECK_INTERVAL
		_avoid_turn = 0.0
		if is_blocked.call(global_position + Vector2.from_angle(_heading) * LOOK_AHEAD):
			var left_blocked: bool = is_blocked.call(global_position + Vector2.from_angle(_heading - 0.8) * LOOK_AHEAD)
			_avoid_turn = TURN_RATE if left_blocked else -TURN_RATE
			if is_blocked.call(global_position):
				dive()
	var wander := sin(_age * 0.5 + _wander_phase) * 0.4
	_heading += (_avoid_turn if _avoid_turn != 0.0 else wander) * delta

func _build_art() -> void:
	_tail = _polygon([Vector2(0, -3), Vector2(-26, -26), Vector2(-16, 0), Vector2(-26, 26), Vector2(0, 3)], BODY_COLOR)
	_tail.position = Vector2(-72, 0)
	_polygon([Vector2(20, -20), Vector2(-8, -50), Vector2(-12, -18)], BODY_COLOR)
	_polygon([Vector2(20, 20), Vector2(-8, 50), Vector2(-12, 18)], BODY_COLOR)
	_polygon([
		Vector2(82, 0), Vector2(62, -14), Vector2(30, -22), Vector2(0, -22), Vector2(-30, -16),
		Vector2(-60, -8), Vector2(-74, -3), Vector2(-74, 3), Vector2(-60, 8), Vector2(-30, 16),
		Vector2(0, 22), Vector2(30, 22), Vector2(62, 14),
	], BODY_COLOR)

	_wake = Node2D.new()
	add_child(_wake)
	_polygon([Vector2(26, -2), Vector2(-40, -30), Vector2(-46, -24), Vector2(20, 2)], WAKE_COLOR, _wake)
	_polygon([Vector2(26, 2), Vector2(-40, 30), Vector2(-46, 24), Vector2(20, -2)], WAKE_COLOR, _wake)
	_polygon([Vector2(30, 0), Vector2(22, -6), Vector2(14, 0), Vector2(22, 6)], WAKE_COLOR, _wake)

	_polygon([Vector2(22, 0), Vector2(-26, -7), Vector2(-20, 0), Vector2(-26, 7)], FIN_COLOR)
	_polygon([Vector2(22, 0), Vector2(-20, 0), Vector2(-26, 7)], FIN_SHADE_COLOR)

func _polygon(points: Array[Vector2], color: Color, parent: Node = self) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array(points)
	polygon.color = color
	parent.add_child(polygon)
	return polygon
