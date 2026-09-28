class_name SharkSpawner
extends Node2D
## Now and then surfaces a shark somewhere in the ocean the camera can see.
## Sits between the water and the terrain in draw order (z_index -950), so
## sharks swim over the sea but under the shallows and land. Sharks keep
## `shore_clearance` away from any island.

@export var terrain_path: NodePath = ^"../Terrain"
@export var max_sharks: int = 2
## Seconds between sharks. Waits the full gap again after a failed attempt.
@export var spawn_interval := Vector2(15.0, 40.0)
@export var first_spawn_delay := Vector2(6.0, 15.0)
@export var speed_range := Vector2(60.0, 110.0)
@export var lifetime_range := Vector2(14.0, 28.0)
@export var shore_clearance: float = 320.0
## Sharks this far past the edge of the view are removed.
@export var despawn_margin: float = 1500.0

const SPAWN_ATTEMPTS := 16
const CLEARANCE_SAMPLES := 8

var _terrain: TerrainNetwork
var _spawn_timer: float = 0.0
var _sharks: Array[Shark] = []

func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as TerrainNetwork
	if _terrain != null:
		_terrain.ensure_built()
	_spawn_timer = randf_range(first_spawn_delay.x, first_spawn_delay.y)

func _process(delta: float) -> void:
	if _terrain == null:
		return
	var view := _visible_rect()
	_sharks = _sharks.filter(func(shark) -> bool: return is_instance_valid(shark) and not shark.is_queued_for_deletion())
	for shark in _sharks:
		if not view.grow(despawn_margin).has_point(shark.position):
			shark.queue_free()

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)
	if _sharks.size() < max_sharks:
		_try_spawn(view)

func _try_spawn(view: Rect2) -> void:
	for i in SPAWN_ATTEMPTS:
		var spot := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
		if _is_blocked(to_global(spot)):
			continue
		var shark := Shark.new()
		shark.position = spot
		shark.rotation = randf() * TAU
		shark.speed = randf_range(speed_range.x, speed_range.y)
		shark.lifetime = randf_range(lifetime_range.x, lifetime_range.y)
		shark.is_blocked = _is_blocked
		add_child(shark)
		_sharks.append(shark)
		return

func _is_blocked(global_point: Vector2) -> bool:
	var point := _terrain.to_local(global_point)
	if _terrain.is_on_land(point):
		return true
	for i in CLEARANCE_SAMPLES:
		if _terrain.is_on_land(point + Vector2.from_angle(TAU * i / CLEARANCE_SAMPLES) * shore_clearance):
			return true
	return false

func _visible_rect() -> Rect2:
	var to_local_transform := get_global_transform_with_canvas().affine_inverse()
	var viewport_rect := get_viewport().get_visible_rect()
	var corner_a := to_local_transform * viewport_rect.position
	var corner_b := to_local_transform * viewport_rect.end
	return Rect2(corner_a, corner_b - corner_a).abs()
