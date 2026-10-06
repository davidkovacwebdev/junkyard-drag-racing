class_name CritterSpawner
extends Node2D
## Base for spawners that keep a few wandering critters around the camera (the
## beach gulls, the desert tumbleweeds). Every so often it picks a spot just
## outside the view, so critters get driven or blown into frame instead of
## popping in, and it removes any that end up far off screen.
##
## Critters are added to this node's **parent**, the Y-sorted `Sortables` in
## main.tscn, so each one sorts against the car by its own ground Y.
##
## Subclasses override `_is_good_spot()` and `_spawn_at()`, and optionally
## `_spot_outside()` to choose which edge critters come in from.

@export var terrain_path: NodePath = ^"../../Terrain"
@export var max_critters: int = 4
@export var spawn_interval := Vector2(3.0, 8.0)
## How far outside the view new critters appear.
@export var spawn_margin: float = 200.0
@export var despawn_margin: float = 1600.0

const SPAWN_ATTEMPTS := 12

var _terrain: TerrainNetwork
var _spawn_timer: float = 0.0
var _critters: Array[Node2D] = []

func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as TerrainNetwork
	if _terrain != null:
		_terrain.ensure_built()
	_spawn_timer = randf_range(0.0, spawn_interval.y)

func _process(delta: float) -> void:
	if _terrain == null:
		return
	var view := view_rect(self)
	_critters = _critters.filter(func(critter) -> bool: return is_instance_valid(critter) and not critter.is_queued_for_deletion())
	for critter in _critters:
		if not view.grow(despawn_margin).has_point(critter.global_position):
			critter.queue_free()

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = randf_range(spawn_interval.x, spawn_interval.y)
	if _critters.size() >= max_critters:
		return
	for i in SPAWN_ATTEMPTS:
		var spot := _spot_outside(view)
		if not _is_good_spot(spot):
			continue
		for critter in _spawn_at(spot):
			get_parent().add_child(critter)
			_critters.append(critter)
		return

## True if a critter may appear at `global_point`.
func _is_good_spot(_global_point: Vector2) -> bool:
	return false

## The critters to add at `global_point`, not yet in the tree.
func _spawn_at(_global_point: Vector2) -> Array[Node2D]:
	return []

## A random point in the band just outside the view, on any side.
func _spot_outside(view: Rect2) -> Vector2:
	var direction := Vector2.from_angle(randf() * TAU)
	var start := view.get_center() + direction.orthogonal() * randf_range(-0.5, 0.5) * view.size.length() * 0.5
	return _edge_beyond(view, start, direction)

## Where a ray from `from` (inside `view`) along `direction` leaves the view,
## pushed `spawn_margin` further out.
func _edge_beyond(view: Rect2, from: Vector2, direction: Vector2) -> Vector2:
	var grown := view.grow(spawn_margin)
	var reach := INF
	if absf(direction.x) > 0.0001:
		reach = minf(reach, ((grown.end.x - from.x) if direction.x > 0.0 else (from.x - grown.position.x)) / absf(direction.x))
	if absf(direction.y) > 0.0001:
		reach = minf(reach, ((grown.end.y - from.y) if direction.y > 0.0 else (from.y - grown.position.y)) / absf(direction.y))
	return from + direction * maxf(reach, 0.0)

## The camera's view in global coordinates, as seen from `node`'s viewport.
## Critters use it too, to know when they're out of sight.
static func view_rect(node: CanvasItem) -> Rect2:
	var to_world := node.get_viewport().get_canvas_transform().affine_inverse()
	var viewport_rect := node.get_viewport().get_visible_rect()
	var corner_a := to_world * viewport_rect.position
	var corner_b := to_world * viewport_rect.end
	return Rect2(corner_a, corner_b - corner_a).abs()
