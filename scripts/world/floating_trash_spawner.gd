class_name FloatingTrashSpawner
extends Node2D
## Now and then, a scrap of junk drifts into view on the open water — a
## bottle, a tire, a bit of driftwood — bobbing on the surface and slowly
## spinning as it drifts, then fades out or floats off-screen. Purely
## cosmetic ambience, much rarer than SharkSpawner's sharks, which this
## mirrors closely: same visible-rect spawn area, same shore-clearance
## check so nothing spawns already beached, same fade in/out lifecycle.

@export var terrain_path: NodePath = ^"../Terrain"
@export var max_items: int = 4
## Seconds between spawns. Waits the full gap again after a failed attempt.
@export var spawn_interval := Vector2(6.0, 15.0)
@export var first_spawn_delay := Vector2(2.0, 6.0)
@export var drift_speed_range := Vector2(6.0, 18.0)
@export var lifetime_range := Vector2(30.0, 55.0)
## Kept this far from any island so nothing spawns already beached. Smaller
## than a shark's, since trash drifting near a shore is normal — it just
## shouldn't spawn already sitting on the sand.
@export var shore_clearance: float = 150.0
## Trash this far past the edge of the view is removed.
@export var despawn_margin: float = 800.0

const SPAWN_ATTEMPTS := 16
const CLEARANCE_SAMPLES := 8

var _terrain: TerrainNetwork
var _spawn_timer: float = 0.0
var _items: Array[FloatingTrash] = []

func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as TerrainNetwork
	if _terrain != null:
		_terrain.ensure_built()
	_spawn_timer = randf_range(first_spawn_delay.x, first_spawn_delay.y)

func _process(delta: float) -> void:
	if _terrain == null:
		return
	var view := _visible_rect()
	_items = _items.filter(func(item) -> bool: return is_instance_valid(item) and not item.is_queued_for_deletion())
	for item in _items:
		if not view.grow(despawn_margin).has_point(item.position):
			item.queue_free()

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)
	if _items.size() < max_items:
		_try_spawn(view)

func _try_spawn(view: Rect2) -> void:
	for i in SPAWN_ATTEMPTS:
		var spot := Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y))
		if _is_blocked(to_global(spot)):
			continue
		var item := FloatingTrash.new()
		item.position = spot
		item.drift_dir = Vector2.from_angle(randf() * TAU)
		item.drift_speed = randf_range(drift_speed_range.x, drift_speed_range.y)
		item.lifetime = randf_range(lifetime_range.x, lifetime_range.y)
		add_child(item)
		_items.append(item)
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
