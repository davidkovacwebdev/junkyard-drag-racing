class_name JunkyardPile
extends Node2D
## A heap of junk: irregular scrap chunks (real RigidBody2D physics, so the car
## can plough into it and scatter it) piled into a mound, with real equippable
## parts planted in it — the salvage the yard's crane fishes out.
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
##
## The parts are *in* the heap, not in a tidy ring beside it: each one is
## planted on the mound's surface at PartScale.WORLD_SCALE — the size it would
## be if it were bolted to the player's car — and every junk chunk that would
## have overlapped it is left out of the plan (see `_without_clashes()`). With
## parts in the heap it's more important than ever that nothing spawns
## interpenetrating, so the calm-heap rules above carry over untouched.
##
## `get_grabbable_parts()` / `next_grabbable_part()` / `take_part()` are the
## contract with the crane: the crane asks for the next part, swings over to
## it, and tells the pile when it has it. Whatever it actually clamps onto is
## what the player ends up owning.

## Half-width of the mound's base.
@export var radius: float = 190.0
## Mound height as a fraction of `radius`.
@export var height_scale: float = 0.8
## Smallest / largest junk chunk (max vertex distance from its centre).
@export var chunk_min: float = 15.0
@export var chunk_max: float = 30.0
## How many salvageable parts to plant in the heap for the crane to pick out.
## One that can't find a free spot is skipped rather than forced to overlap.
@export var part_count: int = 5
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

## The parts planted in the heap, in the order they were planted. The crane
## takes them off this list as it fishes them out.
var _parts: Array[Node2D] = []

func _ready() -> void:
	var rng := _rng()
	queue_redraw()
	# Parts are planned first: the chunk plan has to know where they sit, so it
	# can leave out the junk they're resting on.
	var part_slots := _plan_part_slots(rng)
	for slot in _without_clashes(_plan_slots(rng), part_slots):
		_spawn_chunk(slot, rng)
	for slot in part_slots:
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
## Each slot is `{pos, center, r}`: `center` is the chunk's middle (the same
## point as `pos` for a chunk, but *not* for a part, whose origin isn't its
## middle), so `_slots_clear()` can compare any two slots' footprints.
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
			var single := Vector2(0.0, centre_y)
			slots.append({"pos": single, "center": single, "r": row_r})
		else:
			var step := row_r * 2.0 + rng.randf_range(3.0, 9.0)
			var count := maxi(1, int(half * 2.0 / step) + 1)
			var x := -step * float(count - 1) * 0.5
			for i in count:
				var pos := Vector2(x, centre_y)
				slots.append({
					"pos": pos,
					"center": pos,
					"r": row_r * rng.randf_range(0.85, 1.0),
				})
				x += step
		stack_y = centre_y - row_r - 2.0
		row_r = maxf(chunk_min, row_r * 0.8)
		row += 1
	return slots

## Where the salvageable parts go, and which part goes where.
##
## A part is planted on the mound's surface — the top half of the same ellipse
## `_plan_slots()` stacks its rows against — and its slot is measured from the
## part's *real* art before placement, because the clearances have to be: at
## world scale a boat body is 73px across and a wheel 25px, and spacing those
## the same way is what keeps the heap calm. Slots are `{pos, center, r,
## data}` like the chunk slots, so `_without_clashes()` can drop the chunks a
## part would have been planted through.
func _plan_part_slots(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if part_count <= 0:
		return slots
	var pool := _part_pool()
	if pool.is_empty():
		return slots
	for i in part_count:
		var data: PartData = pool[rng.randi() % pool.size()]
		var probe := _instantiate(data)
		if probe == null:
			continue
		probe.position = Vector2.ZERO
		PartScale.apply_to(probe)
		var bounds := PartScale.measure_bounds(probe)
		probe.free()
		# A little margin absorbs the tilt `_spawn_part()` adds on top.
		var reach := maxf(bounds.size.x, bounds.size.y) * 0.5 * 1.15
		for attempt in 30:
			var x := rng.randf_range(-radius * 0.85, radius * 0.85)
			# Origin placed so the bottom of the art rests on the mound at x.
			var pos := Vector2(x, _surface_y(x) - bounds.end.y)
			var center := pos + bounds.get_center()
			if not _slots_clear(slots, center, reach):
				continue
			slots.append({"pos": pos, "center": center, "r": reach, "data": data})
			break
	return slots

## Height of the mound's surface at `x`, in this node's space.
func _surface_y(x: float) -> float:
	var t := clampf(absf(x) / radius, 0.0, 1.0)
	return -radius * height_scale * sqrt(maxf(1.0 - t * t, 0.0))

## Junk chunks minus the ones a part would have been planted through. A part's
## footprint is treated as a circle of `r` around its middle — close enough
## that nothing ends up sharing space, which is the whole point.
func _without_clashes(chunk_slots: Array[Dictionary], part_slots: Array[Dictionary]) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for slot in chunk_slots:
		if _slots_clear(part_slots, slot["center"], float(slot["r"])):
			kept.append(slot)
	return kept

func _slots_clear(existing: Array[Dictionary], center: Vector2, r: float) -> bool:
	for slot in existing:
		var other: Vector2 = slot["center"]
		if center.distance_to(other) < r + float(slot["r"]) + 4.0:
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

## A part scene from the catalog, planted on the mound at the size it wears on
## the player's car. Its slot was already measured and grounded while planning,
## so this only has to build it and drop it in place.
func _spawn_part(slot: Dictionary, rng: RandomNumberGenerator) -> void:
	var node := _instantiate(slot["data"])
	if node == null:
		return
	node.position = Vector2.ZERO
	# A slight tilt, purely so the heap doesn't look arranged — it also sinks
	# the art a couple of pixels into the mound, which reads as junk lying *in*
	# the heap rather than balanced on top of it.
	node.rotation = rng.randf_range(-0.18, 0.18)
	PartScale.apply_to(node)
	_settle(node as RigidBody2D)
	add_child(node)
	node.name = "Part%d" % _parts.size()
	node.position = slot["pos"]
	_parts.append(node)

## Every equippable part in the catalog — the same pool the garage browses.
func _part_pool() -> Array[PartData]:
	var pool: Array[PartData] = []
	pool.append_array(PartDatabase.bodies)
	pool.append_array(PartDatabase.wheels)
	pool.append_array(PartDatabase.engines)
	return pool

## A part's real scene, or null when the catalog entry has no scene or its
## root isn't a Node2D.
func _instantiate(data: PartData) -> Node2D:
	if data == null or data.scene_path.is_empty():
		return null
	var scene := load(data.scene_path) as PackedScene
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	if not (instance is Node2D):
		instance.free()
		return null
	return instance as Node2D

# --- Salvage -------------------------------------------------------------------

## The parts still lying in the heap — what the crane can fish out.
func get_grabbable_parts() -> Array[Node2D]:
	return _parts.duplicate()

## The part the crane should go for next: the nearest one to `from`, so the
## claw works the heap from where it already is instead of swinging across the
## yard to the far end first. Null once the heap has been picked clean.
func next_grabbable_part(from: Vector2 = Vector2.ZERO) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for part in _parts:
		if not is_instance_valid(part):
			continue
		var distance := part.global_position.distance_to(from)
		if distance < best_distance:
			best_distance = distance
			best = part
	return best

## The crane has lifted this part out of the heap, so it's spoken for: it stops
## being a candidate for the next grab.
func take_part(part: Node2D) -> void:
	_parts.erase(part)

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
