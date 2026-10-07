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
@export var junk_chunk_count: int = 10:
	set(value):
		junk_chunk_count = maxi(value, 0)
		if is_node_ready():
			_assemble()
@export var part_count: int = 6:
	set(value):
		part_count = maxi(value, 0)
		if is_node_ready():
			_assemble()
## Sets the heap's size: its base spans `HEAP_WIDTH_SHARE` times this either
## side of centre and its peak stands `HEAP_HEIGHT_SHARE` times this high.
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
@export var crane_scale: float = 0.75:
	set(value):
		crane_scale = maxf(value, 0.01)
		if is_node_ready():
			_assemble()
## How much cable the winch has paid out, in the crane's own (unscaled) units.
## Long enough that the parked claw reaches down to the heap instead of dangling
## over open ground.
@export var crane_hoist: float = 420.0:
	set(value):
		crane_hoist = value
		if is_node_ready():
			_assemble()
## Ground left between the heap's right foot and the crane's tracks.
@export var crane_gap: float = 16.0:
	set(value):
		crane_gap = value
		if is_node_ready():
			_assemble()

## The heap's base half-width, as a multiple of `radius`.
const HEAP_WIDTH_SHARE := 1.4
## The peak's height, as a multiple of `radius`.
const HEAP_HEIGHT_SHARE := 1.25
## The heap's outline, foot to foot over a peak left of centre, as (x, height)
## shares of the base half-width and the peak height. Lumpy, not a dome.
const HEAP_OUTLINE: Array[Vector2] = [
	Vector2(-1.0, 0.0), Vector2(-0.8, 0.24), Vector2(-0.62, 0.5), Vector2(-0.42, 0.7),
	Vector2(-0.24, 0.62), Vector2(-0.06, 1.0), Vector2(0.18, 0.9), Vector2(0.4, 0.7),
	Vector2(0.56, 0.6), Vector2(0.78, 0.34), Vector2(1.0, 0.0),
]
## Where the shaded right flank starts along HEAP_OUTLINE (the peak).
const HEAP_PEAK_INDEX := 5
const MOUND_COLOR := Color(0.42, 0.34, 0.22, 1)

const JUNK_COLORS := [
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
	crane.add_to_group(OffscreenCuller.GROUP)
	crane.scale = Vector2(crane_scale, crane_scale)
	_art.add_child(crane)
	# Trolley and cable are the machine's own controls, and `_ready()` parks them
	# at the exported defaults — so set them after the node is in the tree, or
	# the parked values win.
	crane.place_hoist(crane_hoist)
	# Claw hangs at `-trolley` in the crane's local x, so standing the tracks at
	# `trolley * scale` lands the claw above the heap centre (local x 0).
	# Tracks on the ground beside the heap's right foot. The trolley is run out
	# so the claw hangs over the peak.
	var track_half := crane.track_width * 0.5 * crane_scale
	crane.position = Vector2(radius * HEAP_WIDTH_SHARE + crane_gap + track_half, 0.0)
	crane.place_trolley((crane.position.x - heap_outline(radius)[HEAP_PEAK_INDEX].x) / crane_scale)
	if not Engine.is_editor_hint():
		var tracks := Rect2(-crane.track_width * 0.5, -crane.track_height * 0.5, crane.track_width, crane.track_height * 0.5)
		RoundedRectShape.add_solid(crane, tracks)

## The heap, standing on the node's origin (the ground line, which is also its
## y-sort point).
func _spawn_mound(rng: RandomNumberGenerator) -> void:
	build_mound(_art, radius, rng)

## One lumpy mound, a darker right flank and a ground shadow, added to `parent`.
## Shared with the yard interior's JunkyardPile so both heaps look the same.
static func build_mound(parent: Node2D, heap_radius: float, rng: RandomNumberGenerator) -> void:
	var outline := heap_outline(heap_radius)
	var half_width := heap_radius * HEAP_WIDTH_SHARE
	var shadow := Polygon2D.new()
	shadow.color = UiPalette.SHADOW
	shadow.polygon = FlatProps.octagon(Vector2(16.0, 2.0), half_width + 20.0, 24.0)
	parent.add_child(shadow)
	var mound := Polygon2D.new()
	mound.color = MOUND_COLOR
	var jittered := PackedVector2Array()
	for i in outline.size():
		var lump := 0.0 if i == 0 or i == outline.size() - 1 else rng.randf_range(-6.0, 6.0)
		jittered.append(outline[i] + Vector2(0.0, lump))
	mound.polygon = jittered
	parent.add_child(mound)
	var flank := Polygon2D.new()
	flank.color = MOUND_COLOR.darkened(0.25)
	var flank_points := jittered.slice(HEAP_PEAK_INDEX)
	flank_points.append(Vector2(outline[HEAP_PEAK_INDEX].x + half_width * 0.25, 0.0))
	flank.polygon = flank_points
	parent.add_child(flank)

## The heap's silhouette at `heap_radius`, standing on y = 0. Shared with the
## yard interior's JunkyardPile so both heaps are the same shape.
static func heap_outline(heap_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for share in HEAP_OUTLINE:
		points.append(Vector2(share.x * heap_radius * HEAP_WIDTH_SHARE, -share.y * heap_radius * HEAP_HEIGHT_SHARE))
	return points

## A spot on the heap's face, kept clear of its edges.
func _random_point_in_pile(rng: RandomNumberGenerator) -> Vector2:
	var outline := heap_outline(radius)
	var half_width := radius * HEAP_WIDTH_SHARE
	for attempt in 12:
		var point := Vector2(rng.randf_range(-half_width, half_width) * 0.8, -rng.randf_range(0.1, 0.85) * radius * HEAP_HEIGHT_SHARE)
		if Geometry2D.is_point_in_polygon(point, outline):
			return point
	return Vector2(0.0, -radius * 0.4)

func _spawn_junk_chunk(rng: RandomNumberGenerator) -> void:
	var chunk := RigidBody2D.new()
	# No gravity in this top-down world — junk just sits where it lands
	# until the car actually bumps into it, instead of drifting off.
	chunk.gravity_scale = 0.0
	chunk.can_sleep = false
	# Only the car (layer 2) moves it. Against the heap's own footprint or the
	# other chunks it starts inside, it would be shoved off the pile at once.
	chunk.collision_mask = 2
	_art.add_child(chunk)
	chunk.position = _random_point_in_pile(rng)
	chunk.rotation = rng.randf_range(0.0, TAU)

	var poly := junk_chunk_polygon(rng)

	var visual := Polygon2D.new()
	visual.polygon = poly
	visual.color = JUNK_COLORS[rng.randi() % JUNK_COLORS.size()]
	chunk.add_child(visual)

	var collision := CollisionPolygon2D.new()
	collision.polygon = poly
	chunk.add_child(collision)

## A slab of scrap: a quad with one slanted side. Shared with JunkyardPile.
static func junk_chunk_polygon(rng: RandomNumberGenerator) -> PackedVector2Array:
	var size := Vector2(rng.randf_range(14.0, 30.0), rng.randf_range(8.0, 16.0))
	return PackedVector2Array([
		Vector2(-size.x, -size.y), Vector2(size.x, -size.y),
		Vector2(size.x * 0.8, size.y), Vector2(-size.x, size.y),
	])

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
	pool.append_array(PartDatabase.junk_bodies)
	pool.append_array(PartDatabase.junk_wheels)
	pool.append_array(PartDatabase.junk_engines)
	pool.append_array(PartDatabase.junk_accessories)
	if pool.is_empty():
		return
	var part: PartData = pool[rng.randi() % pool.size()]
	var instance := PartFactory.instantiate(part)
	if instance == null:
		return
	if instance is RigidBody2D:
		# Scenery, not physics: parts are scattered blind and can land
		# overlapping, and two live bodies shoved apart from inside each other
		# can blow up to NaN (a ceiling fan wheel did), which then poisons the
		# player's car on contact. Frozen, they still block the car.
		instance.gravity_scale = 0.0
		instance.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		instance.freeze = true
	_art.add_child(instance)
	instance.position = _random_point_in_pile(rng)
	instance.rotation = rng.randf_range(0.0, TAU)
	PartScale.apply_to(instance)
