@tool
class_name Junkyard
extends Node2D
## A pile of scrap on the world map — a cluster of small colored junk
## chunks (real RigidBody2D physics, styled like PartShatter's debris,
## so the car can crash into and scatter them) plus a handful of actual
## equippable parts pulled straight from PartDatabase, scattered in
## among the junk. A parked scrap crane stands over the heap so the
## landmark reads as a working yard rather than a bare pile. Purely a
## landmark/prop for now — digging through it for loot is a separate,
## later feature.
##
## @tool so the landmark is visible in the 2D editor instead of showing up as an
## empty Node2D. The whole heap — mound, crane, junk — is assembled into an
## `_art` root that is added with no `owner`, so it renders in the editor
## viewport but is never written into the saved scene. Real parts need the
## `PartDatabase` autoload, which doesn't exist while editing, so the editor
## preview deliberately shows the heap and the crane without them.

@export_group("Junk")
@export var junk_chunk_count: int = 18:
	set(value):
		junk_chunk_count = maxi(value, 0)
		if is_node_ready():
			_assemble()
@export var part_count: int = 6:
	set(value):
		part_count = maxi(value, 0)
		if is_node_ready():
			_assemble()
@export var radius: float = 160.0:
	set(value):
		radius = maxf(value, 1.0)
		if is_node_ready():
			_assemble()
## Seeds the junk scatter. Fixed so the heap is laid out the same way every time
## the scene is opened in the editor, and so tweaking an export below doesn't
## reshuffle the whole pile on every rebuild.
@export var scatter_seed: int = 20240923:
	set(value):
		scatter_seed = value
		if is_node_ready():
			_assemble()

@export_group("Crane")
## Whether the scrap crane is drawn over the heap at all.
@export var crane_enabled: bool = true:
	set(value):
		crane_enabled = value
		if is_node_ready():
			_assemble()
## How big the crane is against the junk heap. The machine is authored for the
## interior yard (a 1900x1200 lot) at scale 1, so on the map it has to come down
## to the pile's size or the boom towers clear off the landmark.
@export var crane_scale: float = 0.5:
	set(value):
		crane_scale = maxf(value, 0.01)
		if is_node_ready():
			_assemble()
## How much cable the winch has paid out, in the crane's own (unscaled) units.
## Long enough that the parked claw reaches down to the heap instead of dangling
## over open ground.
@export var crane_hoist: float = 280.0:
	set(value):
		crane_hoist = value
		if is_node_ready():
			_assemble()
## How far behind the heap centre the tracks sit, as a fraction of `radius`. The
## base is set back a touch so the pile reads as heaped up in front of the crane.
@export var crane_depth: float = 0.15:
	set(value):
		crane_depth = value
		if is_node_ready():
			_assemble()

const _JUNK_COLORS := [
	Color(0.45, 0.4, 0.35, 1),
	Color(0.55, 0.3, 0.2, 1),
	Color(0.3, 0.3, 0.32, 1),
	Color(0.6, 0.5, 0.2, 1),
	Color(0.4, 0.45, 0.3, 1),
	Color(0.5, 0.15, 0.15, 1),
]

## The assembled visuals, kept so a rebuild can drop the old heap instead of
## stacking a second one on top of it. Added with no `owner`, so it renders in
## the editor but is never saved into the scene.
var _art: Node2D

func _ready() -> void:
	_assemble()

## (Re)build the landmark. Cheap and idempotent — it frees any previous art
## first, so the editor can call it on every export change without piling up
## heaps. Order matters for drawing: mound, then the crane standing over it,
## then the loose junk nearest the camera. See `_spawn_crane()`.
func _assemble() -> void:
	_clear_art()
	_art = Node2D.new()
	_art.name = "Art"
	add_child(_art)

	var rng := _rng()
	_spawn_mound(rng)
	_spawn_crane()
	for i in junk_chunk_count:
		_spawn_junk_chunk(rng)
	# The scattered parts are real catalogue scenes, and PartDatabase is an
	# autoload — unreachable from the editor. Runtime only.
	if Engine.is_editor_hint():
		return
	for i in part_count:
		_spawn_random_part(rng)

## Drop the assembled art, if any. `free()` rather than `queue_free()` so a
## rebuild in the same frame can't briefly show both heaps.
func _clear_art() -> void:
	if _art == null or not is_instance_valid(_art):
		_art = null
		return
	if _art.get_parent() != null:
		_art.get_parent().remove_child(_art)
	_art.free()
	_art = null

## Seeded so the scatter is stable across rebuilds and editor reloads.
func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	return rng

## Stand the scrap crane over the heap — the same `JunkyardCrane` the player
## drives in the crane pen, parked here as scenery (it owns its own idle sway).
##
## Two things make it read right. Added after the mound but before the loose
## junk, so the heap is behind it and the scattered chunks are in front. And the
## boom reaches out over the heap on the -x side, so the tracks are placed
## `trolley` (scaled) to the +x side — that's what puts the hanging claw down the
## centre of the pile rather than off to one side of it.
func _spawn_crane() -> void:
	if not crane_enabled or crane_scale <= 0.0:
		return
	var crane := JunkyardCrane.new()
	crane.name = "Crane"
	crane.scale = Vector2(crane_scale, crane_scale)
	_art.add_child(crane)
	# Trolley and cable are the machine's own controls, and `_ready()` parks them
	# at the exported defaults — so set them after the node is in the tree, or
	# the parked values win.
	crane.place_trolley(crane.trolley_offset)
	crane.place_hoist(crane_hoist)
	# Claw hangs at `-trolley` in the crane's local x, so standing the tracks at
	# `trolley * scale` lands the claw above the heap centre (local x 0).
	crane.position = Vector2(crane.trolley * crane_scale, -radius * crane_depth)

## Dirt-colored base underneath the junk so the cluster reads as a
## heaped-up hill rather than debris just floating on bare sand.
func _spawn_mound(rng: RandomNumberGenerator) -> void:
	var mound := Polygon2D.new()
	mound.color = Color(0.32, 0.26, 0.17, 1)
	var points := PackedVector2Array()
	var point_count := 14
	for i in point_count:
		var angle := TAU * i / point_count
		var r := radius * rng.randf_range(0.85, 1.15)
		points.append(Vector2(cos(angle), sin(angle)) * r)
	mound.polygon = points
	_art.add_child(mound)

func _random_point_in_pile(rng: RandomNumberGenerator) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var r := radius * sqrt(rng.randf())
	return Vector2(cos(angle), sin(angle)) * r

func _spawn_junk_chunk(rng: RandomNumberGenerator) -> void:
	var chunk := RigidBody2D.new()
	# No gravity in this top-down world — junk just sits where it lands
	# until the car actually bumps into it, instead of drifting off.
	chunk.gravity_scale = 0.0
	chunk.can_sleep = false
	_art.add_child(chunk)
	chunk.position = _random_point_in_pile(rng)
	chunk.rotation = rng.randf_range(0.0, TAU)

	var size := rng.randf_range(10.0, 22.0)
	var poly := PackedVector2Array([
		Vector2(-size, -size), Vector2(size, -size),
		Vector2(size, size), Vector2(-size, size),
	])

	var visual := Polygon2D.new()
	visual.polygon = poly
	visual.color = _JUNK_COLORS[rng.randi() % _JUNK_COLORS.size()]
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
##
## Runtime only: it reads `PartDatabase`, an autoload that isn't registered
## while the editor has the scene open.
func _spawn_random_part(rng: RandomNumberGenerator) -> void:
	var pool: Array[PartData] = []
	pool.append_array(PartDatabase.bodies)
	pool.append_array(PartDatabase.wheels)
	pool.append_array(PartDatabase.engines)
	if pool.is_empty():
		return
	var part: PartData = pool[rng.randi() % pool.size()]
	if part.scene_path.is_empty():
		return
	var instance: Node2D = (load(part.scene_path) as PackedScene).instantiate()
	if instance is RigidBody2D:
		instance.gravity_scale = 0.0
	_art.add_child(instance)
	instance.position = _random_point_in_pile(rng)
	instance.rotation = rng.randf_range(0.0, TAU)
	PartScale.apply_to(instance)
