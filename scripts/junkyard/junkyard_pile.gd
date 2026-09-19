class_name JunkyardPile
extends Node2D
## A heap of junk: irregular scrap chunks (real RigidBody2D physics, so the car
## can plough into it and scatter it) piled into a mound, with a few real parts
## from PartDatabase lying around the skirt of the heap.
##
## The pile has to be *calm* on arrival, and the naive version wasn't: chunks
## were scattered at random inside a radius, so most of them spawned
## overlapping and the solver blasted them apart on the first physics tick —
## a heap that visibly explodes every time you walk in.
##
## Two things fix that:
##   - `_plan_slots()` builds the mound in rows and never places two chunks
##     closer together than the sum of their reaches, so nothing overlaps at
##     spawn and there is no penetration to resolve.
##   - every body gets zero gravity, heavy damping and no initial velocity, so
##     with no contacts there is nothing left to jitter. Sleep is deliberately
##     *not* used: a sleeping body can be stubborn about waking when the car's
##     kinematic body shoves it, and a heap you can't disturb isn't a heap.
##
## Art space (same as TrashProp): origin is the mound's ground line, +y down,
## so it Y-sorts against the car like every other prop in the world.

## Half-width of the mound's base.
@export var radius: float = 190.0
## Mound height as a fraction of `radius`.
@export var height_scale: float = 0.8
## Smallest / largest junk chunk (max vertex distance from its centre).
@export var chunk_min: float = 15.0
@export var chunk_max: float = 30.0
## How many salvaged car parts to drop around the heap.
@export var part_count: int = 5
## Room a salvaged part is allowed to take up, so it can't overlap its
## neighbours: parts are scaled down to fit this.
@export var part_reach: float = 52.0
## Fixed seed = the same pile every visit; 0 = a new pile each time.
@export var pile_seed: int = 4242
@export var mound_color: Color = Color(0.32, 0.26, 0.17, 1)

const _JUNK_COLORS := [
	Color(0.45, 0.4, 0.35, 1),
	Color(0.55, 0.3, 0.2, 1),
	Color(0.3, 0.3, 0.32, 1),
	Color(0.6, 0.5, 0.2, 1),
	Color(0.4, 0.45, 0.3, 1),
	Color(0.5, 0.15, 0.15, 1),
]

## Scratch state for `_measure()`: the art bounds it accumulates, and whether
## anything has been measured yet (a Rect2 built from an empty polygon would
## otherwise read as a zero rect at the origin and look legitimate).
var _measured_bounds := Rect2()
var _measured_valid := false

func _ready() -> void:
	var rng := _rng()
	queue_redraw()
	for slot in _plan_slots(rng):
		_spawn_chunk(slot, rng)
	for slot in _plan_part_slots(rng):
		_spawn_part(slot, rng)

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if pile_seed == 0:
		rng.randomize()
	else:
		rng.seed = pile_seed
	return rng

# --- Layout --------------------------------------------------------------------

## Rows of junk, bottom (widest) to top, each chunk's centre kept clear of
## every chunk already placed and of the row below. The row's half-width
## follows the mound's silhouette so the stack tapers into a heap.
func _plan_slots(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var height := radius * height_scale
	var stack_y := 0.0
	var row_r := chunk_max
	var row := 0
	while row < 32:
		var centre_y := stack_y - row_r
		if centre_y < -height:
			break
		var t := clampf(-centre_y / height, 0.0, 1.0)
		var half := radius * sqrt(maxf(1.0 - t * t, 0.0))
		if half < row_r:
			slots.append({"pos": Vector2(0.0, centre_y), "r": row_r})
		else:
			var step := row_r * 2.0 + rng.randf_range(3.0, 9.0)
			var count := maxi(1, int(half * 2.0 / step) + 1)
			var x := -step * float(count - 1) * 0.5
			for i in count:
				slots.append({
					"pos": Vector2(x, centre_y),
					"r": row_r * rng.randf_range(0.85, 1.0),
				})
				x += step
		stack_y = centre_y - row_r - 2.0
		row_r = maxf(chunk_min, row_r * 0.8)
		row += 1
	return slots

## Salvaged parts lie around the heap rather than in it: they're much bigger
## than a junk chunk at a readable scale, so they get their own ring just
## outside the mound (flattened vertically, so they sit on the ground line
## instead of floating off in the air).
func _plan_part_slots(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if part_count <= 0:
		return slots
	var angle := rng.randf_range(0.0, TAU)
	for i in part_count:
		for attempt in 10:
			var dist := rng.randf_range(
					radius + part_reach + 30.0, radius + part_reach + 190.0)
			var pos := Vector2(cos(angle), sin(angle) * 0.4) * dist
			if _slots_clear(slots, pos, part_reach):
				slots.append({"pos": pos, "r": part_reach})
				break
			angle += 0.8
		angle += TAU / float(part_count)
	return slots

func _slots_clear(existing: Array[Dictionary], pos: Vector2, r: float) -> bool:
	for slot in existing:
		var other: Vector2 = slot["pos"]
		if pos.distance_to(other) < r + float(slot["r"]) + 4.0:
			return false
	return true

# --- Spawning ------------------------------------------------------------------

func _spawn_chunk(slot: Dictionary, rng: RandomNumberGenerator) -> void:
	var pos: Vector2 = slot["pos"]
	var r: float = slot["r"]
	var chunk := RigidBody2D.new()
	_settle(chunk)
	chunk.position = pos
	chunk.rotation = rng.randf_range(0.0, TAU)

	var poly := _chunk_polygon(r, rng)
	var visual := Polygon2D.new()
	visual.polygon = poly
	visual.color = _JUNK_COLORS[rng.randi() % _JUNK_COLORS.size()]
	chunk.add_child(visual)
	var collision := CollisionPolygon2D.new()
	collision.polygon = poly
	chunk.add_child(collision)

	add_child(chunk)
	chunk.name = "Chunk%d" % get_child_count()

## Everything a junk chunk needs to sit dead still until it's hit.
func _settle(body: RigidBody2D) -> void:
	if body == null:
		return
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.linear_damp = 2.5
	body.angular_damp = 2.5

## Irregular blob: evenly spaced vertices at varying distances, so it reads as
## a lump of scrap rather than a die. The largest vertex distance is `r`, which
## is what `_plan_slots()` spaced the neighbours against.
func _chunk_polygon(r: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var count := rng.randi_range(5, 8)
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
		points.append(Vector2(cos(angle), sin(angle)) * r * rng.randf_range(0.72, 1.0))
	return points

## A real part scene from the catalog, scaled down to fit its slot and dropped
## so its art rests on the ground line.
func _spawn_part(slot: Dictionary, rng: RandomNumberGenerator) -> void:
	var pool: Array[PartData] = []
	pool.append_array(PartDatabase.bodies)
	pool.append_array(PartDatabase.wheels)
	pool.append_array(PartDatabase.engines)
	if pool.is_empty():
		return
	var part: PartData = pool[rng.randi() % pool.size()]
	if part.scene_path.is_empty():
		return
	var instance := (load(part.scene_path) as PackedScene).instantiate()
	if not (instance is Node2D):
		instance.free()
		return
	var node := instance as Node2D
	node.position = Vector2.ZERO
	node.rotation = rng.randf_range(-0.35, 0.35)
	node.scale = Vector2.ONE * _fit_scale(node, float(slot["r"]))
	_settle(node as RigidBody2D)
	add_child(node)
	node.position = _grounded_position(node, slot["pos"])

## Scale that keeps a part's art inside `target_reach`. Bodies are ~130px of
## art and wheels ~36px, so without this the wheels would look lost and the
## bodies would overlap half the heap.
func _fit_scale(node: Node2D, target_reach: float) -> float:
	_reset_measure()
	_measure(node, Transform2D())
	if not _measured_valid:
		return 0.4
	var reach := maxf(
			maxf(absf(_measured_bounds.position.x), absf(_measured_bounds.end.x)),
			maxf(absf(_measured_bounds.position.y), absf(_measured_bounds.end.y)))
	if reach <= 0.0:
		return 0.4
	return clampf(target_reach / reach, 0.18, 0.5)

## Where a part has to sit so the bottom of its art touches the ground line at
## `slot_pos` — measured through the instance's own transform, so its tilt and
## scale are accounted for.
func _grounded_position(node: Node2D, slot_pos: Vector2) -> Vector2:
	var target: Vector2 = slot_pos
	_reset_measure()
	_measure(node, node.transform)
	if not _measured_valid:
		return target
	return Vector2(target.x, target.y - _measured_bounds.end.y)

func _reset_measure() -> void:
	_measured_bounds = Rect2()
	_measured_valid = false

## Walk a subtree accumulating the bounds of every Polygon2D / CollisionPolygon2D
## vertex, under `xform`. Recursive because a part's art can be nested.
func _measure(node: Node, xform: Transform2D) -> void:
	if node is Polygon2D:
		for vertex in (node as Polygon2D).polygon:
			_include(xform * vertex)
	elif node is CollisionPolygon2D:
		for vertex in (node as CollisionPolygon2D).polygon:
			_include(xform * vertex)
	for child in node.get_children():
		var child_xform := xform
		if child is Node2D:
			child_xform = xform * (child as Node2D).transform
		_measure(child, child_xform)

func _include(point: Vector2) -> void:
	if _measured_valid:
		_measured_bounds = _measured_bounds.expand(point)
	else:
		_measured_bounds = Rect2(point, Vector2.ZERO)
		_measured_valid = true

# --- Drawing -------------------------------------------------------------------

## Dirt mound under the junk, so the pile reads as a heap rather than debris
## floating on bare ground. Squashed into an ellipse because the world is
## looked at from a shallow angle.
func _draw() -> void:
	var rng := _rng()
	var points := PackedVector2Array()
	var count := 18
	for i in count:
		var angle := TAU * float(i) / float(count)
		var r := radius * rng.randf_range(0.9, 1.12)
		points.append(Vector2(cos(angle), sin(angle) * 0.62) * r)
	draw_colored_polygon(points, mound_color)
