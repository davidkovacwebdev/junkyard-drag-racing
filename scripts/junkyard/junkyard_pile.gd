class_name JunkyardPile
extends Node2D
## A heap of junk inside the yard, built to look like the junkyard landmark on
## the world map (see junkyard.gd): the same lumpy mound with its shaded right
## flank, scrap slabs scattered over its face (real RigidBody2D physics, so the
## car can plough into them and scatter them) and real equippable parts lying
## in among them — the salvage the yard's crane fishes out.
##
## The pile has to be *calm* on arrival. Like the landmark's junk, every body
## only collides with the car (layer 2), so slabs and parts scattered on top of
## each other have nothing to resolve, and zero gravity plus heavy damping keep
## them still until the car hits them. Sleep is deliberately *not* used: a
## sleeping body can be stubborn about waking when the car's kinematic body
## shoves it. Parts are still kept apart from each other so each one reads.
##
## Art space (same as the landmark): origin is the mound's ground line, +y down.
## Not y-sorted inside, so the whole heap sorts against the car at its foot and
## the junk always draws over the mound it's lying on.
##
## `get_grabbable_parts()` / `next_grabbable_part()` / `take_part()` are the
## contract with the crane: the crane asks for the next part, swings over to
## it, and tells the pile when it has it.

## Heap size, in the landmark's units: the base spans
## `Junkyard.HEAP_WIDTH_SHARE` times this either side of centre.
@export var radius: float = 150.0
## How many scrap slabs to scatter over the mound's face.
@export var chunk_count: int = 16
## How many salvageable parts to plant in the heap for the crane to pick out.
@export var part_count: int = 5
## Fixed seed = the same pile every visit; 0 = a new pile each time.
@export var pile_seed: int = 4242

## Attempts per part at finding a spot on the face clear of the other parts.
## One that can't find one is skipped rather than forced to overlap.
const PLACEMENT_ATTEMPTS := 30

## The parts planted in the heap, in the order they were planted. The crane
## takes them off this list as it fishes them out.
var _parts: Array[Node2D] = []
var _outline: PackedVector2Array

func _ready() -> void:
	_outline = Junkyard.heap_outline(radius)
	var rng := _rng()
	Junkyard.build_mound(self, radius, rng)
	var part_slots := _plan_part_slots(rng)
	for i in chunk_count:
		_spawn_chunk(rng)
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

## Where the salvageable parts go, and which part goes where. Each slot is
## `{pos, center, r, data}`: `center` is the middle of the part's real art
## (measured at world scale before placement), which isn't its origin.
func _plan_part_slots(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var pool := _part_pool()
	if pool.is_empty():
		return slots
	for i in part_count:
		var data: PartData = pool[rng.randi() % pool.size()]
		var probe := PartFactory.instantiate(data)
		if probe == null:
			continue
		probe.position = Vector2.ZERO
		PartScale.apply_to(probe)
		var bounds := PartScale.measure_bounds(probe)
		probe.free()
		# A little margin absorbs the tilt `_spawn_part()` adds on top.
		var reach := maxf(bounds.size.x, bounds.size.y) * 0.5 * 1.15
		for attempt in PLACEMENT_ATTEMPTS:
			var center := _random_point_on_face(rng)
			if not _slots_clear(slots, center, reach):
				continue
			slots.append({"pos": center - bounds.get_center(), "center": center, "r": reach, "data": data})
			break
	return slots

## A spot on the mound's face, kept clear of its edges — the same spread the
## landmark scatters its junk over.
func _random_point_on_face(rng: RandomNumberGenerator) -> Vector2:
	var half_width := radius * Junkyard.HEAP_WIDTH_SHARE
	var height := radius * Junkyard.HEAP_HEIGHT_SHARE
	for attempt in 12:
		var point := Vector2(rng.randf_range(-half_width, half_width) * 0.8, -rng.randf_range(0.1, 0.85) * height)
		if Geometry2D.is_point_in_polygon(point, _outline):
			return point
	return Vector2(0.0, -radius * 0.4)

func _slots_clear(existing: Array[Dictionary], center: Vector2, r: float) -> bool:
	for slot in existing:
		var other: Vector2 = slot["center"]
		if center.distance_to(other) < r + float(slot["r"]) + 4.0:
			return false
	return true

# --- Spawning ------------------------------------------------------------------

func _spawn_chunk(rng: RandomNumberGenerator) -> void:
	var chunk := RigidBody2D.new()
	_settle(chunk)
	chunk.position = _random_point_on_face(rng)
	chunk.rotation = rng.randf_range(0.0, TAU)
	var polygon := Junkyard.junk_chunk_polygon(rng)
	var visual := Polygon2D.new()
	visual.polygon = polygon
	visual.color = Junkyard.JUNK_COLORS[rng.randi() % Junkyard.JUNK_COLORS.size()]
	chunk.add_child(visual)
	var collision := CollisionPolygon2D.new()
	collision.polygon = polygon
	chunk.add_child(collision)
	add_child(chunk)
	chunk.name = "Chunk%d" % get_child_count()

## Everything a piece of junk needs to sit dead still until it's hit.
func _settle(body: RigidBody2D) -> void:
	if body == null:
		return
	body.gravity_scale = 0.0
	body.collision_mask = 2
	body.can_sleep = false
	body.linear_damp = 2.5
	body.angular_damp = 2.5

## A part scene from the catalog, lying on the mound at the size it wears on
## the player's car, with a slight tilt so the heap doesn't look arranged.
func _spawn_part(slot: Dictionary, rng: RandomNumberGenerator) -> void:
	var node := PartFactory.instantiate(slot["data"])
	if node == null:
		return
	node.position = Vector2.ZERO
	node.rotation = rng.randf_range(-0.3, 0.3)
	PartScale.apply_to(node)
	_settle(node as RigidBody2D)
	add_child(node)
	node.name = "Part%d" % _parts.size()
	node.position = slot["pos"]
	_parts.append(node)

## Every equippable part in the catalog — the same pool the garage browses.
func _part_pool() -> Array[PartData]:
	var pool: Array[PartData] = []
	pool.append_array(PartDatabase.junk_bodies)
	pool.append_array(PartDatabase.junk_wheels)
	pool.append_array(PartDatabase.junk_engines)
	pool.append_array(PartDatabase.junk_accessories)
	return pool

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
