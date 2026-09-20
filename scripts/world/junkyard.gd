class_name Junkyard
extends Node2D
## A pile of scrap on the world map — a cluster of small colored junk
## chunks (real RigidBody2D physics, styled like PartShatter's debris,
## so the car can crash into and scatter them) plus a handful of actual
## equippable parts pulled straight from PartDatabase, scattered in
## among the junk. Purely a landmark/prop for now — digging through it
## for loot is a separate, later feature.

@export var junk_chunk_count: int = 18
@export var part_count: int = 6
@export var radius: float = 160.0

const _JUNK_COLORS := [
	Color(0.45, 0.4, 0.35, 1),
	Color(0.55, 0.3, 0.2, 1),
	Color(0.3, 0.3, 0.32, 1),
	Color(0.6, 0.5, 0.2, 1),
	Color(0.4, 0.45, 0.3, 1),
	Color(0.5, 0.15, 0.15, 1),
]

func _ready() -> void:
	_spawn_mound()
	for i in junk_chunk_count:
		_spawn_junk_chunk()
	for i in part_count:
		_spawn_random_part()

## Dirt-colored base underneath the junk so the cluster reads as a
## heaped-up hill rather than debris just floating on bare sand.
func _spawn_mound() -> void:
	var mound := Polygon2D.new()
	mound.color = Color(0.32, 0.26, 0.17, 1)
	var points := PackedVector2Array()
	var point_count := 14
	for i in point_count:
		var angle := TAU * i / point_count
		var r := radius * randf_range(0.85, 1.15)
		points.append(Vector2(cos(angle), sin(angle)) * r)
	mound.polygon = points
	add_child(mound)

func _random_point_in_pile() -> Vector2:
	var angle := randf_range(0.0, TAU)
	var r := radius * sqrt(randf())
	return Vector2(cos(angle), sin(angle)) * r

func _spawn_junk_chunk() -> void:
	var chunk := RigidBody2D.new()
	# No gravity in this top-down world — junk just sits where it lands
	# until the car actually bumps into it, instead of drifting off.
	chunk.gravity_scale = 0.0
	chunk.can_sleep = false
	add_child(chunk)
	chunk.position = _random_point_in_pile()
	chunk.rotation = randf_range(0.0, TAU)

	var size := randf_range(10.0, 22.0)
	var poly := PackedVector2Array([
		Vector2(-size, -size), Vector2(size, -size),
		Vector2(size, size), Vector2(-size, size),
	])

	var visual := Polygon2D.new()
	visual.polygon = poly
	visual.color = _JUNK_COLORS[randi() % _JUNK_COLORS.size()]
	chunk.add_child(visual)

	var collision := CollisionPolygon2D.new()
	collision.polygon = poly
	chunk.add_child(collision)

## Real body/wheel/engine scenes pulled from the same catalog the
## garage browses, scattered like junk — the same parts you could equip
## in the garage are lying around here too. They go down at
## PartScale.WORLD_SCALE, i.e. the size the player's car wears them at,
## so a whole car body in the mound is about one car wide rather than
## looming over the one you're driving.
func _spawn_random_part() -> void:
	var pool: Array[PartData] = []
	pool.append_array(PartDatabase.bodies)
	pool.append_array(PartDatabase.wheels)
	pool.append_array(PartDatabase.engines)
	if pool.is_empty():
		return
	var part: PartData = pool[randi() % pool.size()]
	if part.scene_path.is_empty():
		return
	var instance: Node2D = (load(part.scene_path) as PackedScene).instantiate()
	if instance is RigidBody2D:
		instance.gravity_scale = 0.0
	add_child(instance)
	instance.position = _random_point_in_pile()
	instance.rotation = randf_range(0.0, TAU)
	PartScale.apply_to(instance)
