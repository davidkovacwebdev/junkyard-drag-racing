class_name FloatingTrash
extends Node2D
## One scrap of junk drifting on the open water — a bottle, a tire, or a bit
## of driftwood — bobbing gently and spinning slowly as it drifts in a
## straight line, until it floats off-screen or fades out. Spawned and kept
## clear of land by FloatingTrashSpawner. Passive: unlike Shark, it doesn't
## steer away from anything, it just drifts.

enum Kind { BOTTLE, TIRE, PLANK }

const BOB_HEIGHT := 3.0
const BOB_SPEED := 1.3
const SPIN_SPEED_RANGE := Vector2(-0.6, 0.6)
const FADE_TIME := 2.0
const SPLASH_DB := -18.0

var drift_dir: Vector2 = Vector2.RIGHT
var drift_speed: float = 10.0
var lifetime: float = 40.0

var _age: float = 0.0
var _bob_phase: float = 0.0
var _spin_speed: float = 0.0
var _art: Node2D
var _fading_out := false

func _ready() -> void:
	_bob_phase = randf() * TAU
	_spin_speed = randf_range(SPIN_SPEED_RANGE.x, SPIN_SPEED_RANGE.y)
	_build_art(randi() % 3)
	modulate.a = 0.0
	Sfx.play_at(&"trash_splash", global_position, SPLASH_DB)

func _process(delta: float) -> void:
	_age += delta
	if not _fading_out and _age >= lifetime:
		_fading_out = true
	if _fading_out:
		modulate.a = maxf(0.0, modulate.a - delta / FADE_TIME)
		if modulate.a <= 0.0:
			queue_free()
			return
	else:
		modulate.a = minf(1.0, modulate.a + delta / FADE_TIME)

	position += drift_dir * drift_speed * delta
	_art.rotation += _spin_speed * delta
	_art.position.y = sin(_age * BOB_SPEED + _bob_phase) * BOB_HEIGHT

func _build_art(kind: int) -> void:
	_art = Node2D.new()
	add_child(_art)
	match kind:
		Kind.BOTTLE:
			_polygon([
				Vector2(-4, -14), Vector2(4, -14), Vector2(4, -6), Vector2(7, -2),
				Vector2(7, 10), Vector2(-7, 10), Vector2(-7, -2), Vector2(-4, -6),
			], Color(0.3, 0.5, 0.42, 0.85))
			_polygon([Vector2(-7, 3), Vector2(7, 3), Vector2(7, 10), Vector2(-7, 10)],
					Color(0.22, 0.4, 0.33, 0.85))
		Kind.TIRE:
			_polygon(_circle(13.0, 16), Color(0.12, 0.12, 0.13))
			_polygon(_circle(6.5, 16), Color(0.3, 0.48, 0.56, 0.75))
		Kind.PLANK:
			_polygon([Vector2(-20, -4), Vector2(20, -4), Vector2(20, 4), Vector2(-20, 4)],
					Color(0.42, 0.32, 0.2))
			_polygon([Vector2(-20, 1.5), Vector2(20, 1.5), Vector2(20, 4), Vector2(-20, 4)],
					Color(0.34, 0.25, 0.15))

func _circle(radius: float, steps: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in steps:
		points.append(Vector2.from_angle(TAU * i / steps) * radius)
	return points

func _polygon(points: Array[Vector2], color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array(points)
	polygon.color = color
	_art.add_child(polygon)
	return polygon
