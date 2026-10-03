class_name BloodTrail
extends Node2D
## Drops of blood a beaten-up driver leaves behind the map car (see
## CharacterInjuries.current_level() and PlayerCar). Lives on the ground
## decal layer (SkidMarks), so the drops lie flat under everything. One node
## draws every drop, rather than a node per drop, since a heavy trail lays
## a lot of them.
##
## Junk Toy: each drop is one lumpy little hexagon, a smear is one long
## chunky sliver. They sit a while, fade, and are gone.

const BLOOD := Color(0.55, 0.08, 0.08, 1)
const HOLD_TIME := 25.0
const FADE_TIME := 3.0

## Each: {points: PackedVector2Array, age: float}.
var _drops: Array[Dictionary] = []

func _process(delta: float) -> void:
	if _drops.is_empty():
		return
	for drop in _drops:
		drop.age += delta
	while not _drops.is_empty() and _drops[0].age > HOLD_TIME + FADE_TIME:
		_drops.pop_front()
	queue_redraw()

## A round drop about `radius` px across at `at` (world space).
func add_drop(at: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	var corners := 6
	var spin := randf() * TAU
	for i in corners:
		var angle := spin + TAU * i / corners
		points.append(to_local(at) + Vector2(cos(angle), sin(angle) * 0.6) * radius * randf_range(0.75, 1.15))
	_drops.append({points = points, age = 0.0})

## A dragged smear from `from` to `to` (world space), `width` px thick.
func add_smear(from: Vector2, to: Vector2, width: float) -> void:
	var a := to_local(from)
	var b := to_local(to)
	var side := (b - a).orthogonal().normalized() * width * 0.5
	_drops.append({points = PackedVector2Array([a + side, b + side * 0.4, b - side * 0.4, a - side]),
			age = 0.0})

func _draw() -> void:
	for drop in _drops:
		var color := BLOOD
		if drop.age > HOLD_TIME:
			color.a = 1.0 - (drop.age - HOLD_TIME) / FADE_TIME
		draw_colored_polygon(drop.points, color)
