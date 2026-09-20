class_name TrashHeap
extends Node2D
## A real heap of junk, for the crane to dig in.
##
## Unlike the calm, art-directed pile in the yard (see junkyard_pile.gd, which
## has to be placid because the player drives through it), this one is dumped:
## every piece is a real RigidBody2D with gravity on, dropped in from above the
## frame and left to fall, roll and stack into a mound on the pen floor. Nothing
## is placed by hand, so the heap is a different shape every visit and digging
## in it is a genuine guess about what's under the claw.
##
## The heap is also the crane's eyes. `items_at()` is a physics query at the
## jaws, so a grab takes the bodies that are actually there — including the real
## car parts buried in the junk, each of which still carries its own PartData
## and is exactly the part the player ends up owning. It's plural because a
## claw driven down into a heap doesn't pick one thing out: it scoops up
## whatever it passes through on the way down.
##
## Origin is the pen floor, +y down, art extends upward, so it Y-sorts against
## the crane like any other prop.

## How wide the load is tipped out, each side of this node's origin. Keep it
## comfortably inside the pen walls: everything dropped lands where it falls.
@export var drop_half_width: float = 260.0
## Pull the pin from this far up (the junk starts off-screen and rains in).
@export var drop_height: float = 760.0
## Extra height spread over the whole load, so the pieces arrive one after
## another like a truck tipping rather than landing as a single deck.
@export var drop_stagger: float = 420.0
@export var chunk_count: int = 26
## How many real, equippable car parts are buried in the junk.
@export var part_count: int = 6
## Smallest and largest scrap chunk (max vertex distance from its centre).
@export var chunk_min: float = 14.0
@export var chunk_max: float = 32.0
## Scrap a chunk is worth, per pixel of its radius. Tuned so a haul of junk
## covers part of a dig but never all of it — the money is in the parts.
@export var scrap_per_radius: float = 1.5
## Fixed seed = the same heap every visit; 0 = tipped fresh every time.
@export var heap_seed: int = 0

const ITEM_GROUP := &"heap_item"

const _JUNK_COLORS := [
	Color(0.45, 0.4, 0.35, 1),
	Color(0.55, 0.3, 0.2, 1),
	Color(0.3, 0.3, 0.32, 1),
	Color(0.6, 0.5, 0.2, 1),
	Color(0.4, 0.45, 0.3, 1),
	Color(0.5, 0.15, 0.15, 1),
	Color(0.25, 0.35, 0.4, 1),
]

## Everything lying in the heap, in the order it was tipped in.
var _items: Array[Node2D] = []
## Friction/bounce for the junk, shared by every chunk.
var _material: PhysicsMaterial = null

func _ready() -> void:
	var rng := _rng()
	for i in chunk_count:
		_spawn_chunk(rng, i)
	for i in part_count:
		_spawn_part(rng, chunk_count + i)

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if heap_seed == 0:
		rng.randomize()
	else:
		rng.seed = heap_seed
	return rng

# --- What the crane asks -------------------------------------------------------

## Everything the jaws would close on with their tips at `point`: a shape query
## against the physics world, then a walk up from each collider it hits to the
## heap item that owns it. Empty over bare floor — the ground and the pen walls
## are solid, and none of them are for sale.
##
## Plural because a claw being driven down into a heap doesn't pick one thing
## out: it scoops up whatever it passes through (see `CraneRig._sink()`), so one
## dig can come back with several pieces.
func items_at(point: Vector2, radius: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	if _items.is_empty():
		return found
	var shape := CircleShape2D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, point)
	params.collide_with_bodies = true
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 32):
		var item := item_of(hit.get("collider") as Node)
		if item != null and not found.has(item):
			found.append(item)
	return found

## The heap item a node belongs to, walking up from a collider — a part owns its
## own collision shape, and a wrapped engine (see `_wrap()`) owns the shape on
## its parent. Null for anything the heap didn't tip in.
func item_of(node: Node) -> Node2D:
	while node != null:
		# Type-checked first: `_items` is an `Array[Node2D]`, and this walk climbs
		# all the way out of the scene to the root Window, which isn't one.
		if node is Node2D and _items.has(node):
			return node as Node2D
		node = node.get_parent()
	return null

## The PartData an item carries, or null if it's junk. Engines hide a level down
## from the body the jaws actually touched, which is why this looks there too.
func part_of(node: Node) -> PartData:
	var direct: Variant = node.get("part_data")
	if direct is PartData:
		return direct
	for child in node.get_children():
		var nested: Variant = child.get("part_data")
		if nested is PartData:
			return nested
	return null

## Scrap a junk chunk is worth. A part isn't junk and is worth no scrap — it's
## the part itself the player keeps.
func scrap_of(node: Node) -> int:
	if node.has_meta(&"scrap"):
		return int(node.get_meta(&"scrap"))
	return 0

## The crane has hold of this item: it's spoken for and no longer grabbable.
func take(item: Node2D) -> void:
	_items.erase(item)
	if is_instance_valid(item):
		item.remove_from_group(ITEM_GROUP)

func items() -> Array[Node2D]:
	return _items.duplicate()

func count() -> int:
	return _items.size()

func is_empty() -> bool:
	return _items.is_empty()

## Where the heap stands right now: the spread of the pieces' origins, which is
## all a caller needs to know whether the load has finished falling. Empty until
## something has been tipped in.
func item_bounds() -> Rect2:
	var rect := Rect2()
	var started := false
	for item in _items:
		if not is_instance_valid(item):
			continue
		var point := item.global_position
		if started:
			rect = rect.expand(point)
		else:
			rect = Rect2(point, Vector2.ZERO)
			started = true
	return rect

# --- Tipping the load in -------------------------------------------------------

func _spawn_chunk(rng: RandomNumberGenerator, index: int) -> void:
	var radius := rng.randf_range(chunk_min, chunk_max)
	var body := RigidBody2D.new()
	body.mass = maxf(1.0, radius * 0.12)
	body.physics_material_override = _junk_material()
	var poly := _chunk_polygon(radius, rng)
	var visual := Polygon2D.new()
	visual.polygon = poly
	visual.color = _JUNK_COLORS[rng.randi() % _JUNK_COLORS.size()]
	body.add_child(visual)
	var collision := CollisionPolygon2D.new()
	collision.polygon = poly
	body.add_child(collision)
	body.set_meta(&"scrap", maxi(1, int(round(radius * scrap_per_radius))))
	_tip(body, _drop_point(rng, index))
	body.rotation = rng.randf_range(0.0, TAU)

## A real part scene from the same catalog the garage browses, shrunk to the
## size the world's cars wear it at (PartScale), so the heap is in scale with
## the claw.
func _spawn_part(rng: RandomNumberGenerator, index: int) -> void:
	var body := _build_part(rng)
	if body == null:
		return
	_tip(body, _drop_point(rng, index))
	body.rotation = rng.randf_range(0.0, TAU)

## One loose part, ready to be tipped in, or null if the catalog couldn't supply
## one.
##
## Rolls again rather than giving up when a pick turns out to be unusable, so
## `part_count` is what actually lands in the heap. Two picks need rejecting: a
## paddle wheel, which swings its own blade every physics tick (car_paddle.gd)
## and would lie in the pile spinning like a machine digging itself out; and a
## part whose art measures to nothing, which has no shape to collide with.
func _build_part(rng: RandomNumberGenerator) -> RigidBody2D:
	for attempt in 8:
		var node := _instantiate(_random_part(rng))
		if node == null:
			continue
		PartScale.apply_to(node)
		if node is CarPaddle:
			node.free()
			continue
		var body := node as RigidBody2D
		if body == null:
			body = _wrap(node)
		if body == null:
			node.free()
			continue
		body.physics_material_override = _junk_material()
		return body
	push_warning("TrashHeap: no droppable part in 8 rolls — the heap is one part short.")
	return null

## Put a body in the heap and let it fall. The physics side is set *after*
## `_tip()` has added it — a part's own script takes over its mass and sleep
## behaviour in `_ready()`, which runs on entering the tree, and a heap that has
## to settle is exactly where a body should be allowed to fall asleep.
func _tip(body: RigidBody2D, at: Vector2) -> void:
	body.position = at
	add_child(body)
	body.name = "%s%d" % ["Junk" if body.get("part_data") == null else "Part", _items.size()]
	body.mass = clampf(body.mass, 1.0, 30.0)
	body.can_sleep = true
	body.linear_damp = 0.3
	body.angular_damp = 0.5
	body.add_to_group(ITEM_GROUP)
	_items.append(body)

## Where a piece starts its fall: somewhere over the pen, high up, staggered so
## the load arrives over a few seconds instead of all at once.
func _drop_point(rng: RandomNumberGenerator, index: int) -> Vector2:
	var total := maxi(1, chunk_count + part_count)
	var spread := drop_stagger * float(index) / float(total)
	return Vector2(
			rng.randf_range(-drop_half_width, drop_half_width),
			-drop_height - spread)

## Give a part with no physics of its own — an engine — a body to be dropped in.
## Its art is hung on a shape cut to the art's own bounds, so it collides as the
## thing it looks like instead of falling through the floor.
func _wrap(part: Node2D) -> RigidBody2D:
	var bounds := PartScale.measure_bounds(part)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		push_warning("TrashHeap: a part measures to nothing, so there's no shape to drop it in as.")
		return null
	# Re-centre the art on the new body, so the wrapper's origin is the middle
	# of the shape rather than wherever the part's own authoring origin is.
	part.position = -bounds.get_center()
	var body := RigidBody2D.new()
	body.mass = 6.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = bounds.size
	shape.shape = rect
	body.add_child(shape)
	body.add_child(part)
	return body

func _junk_material() -> PhysicsMaterial:
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = 0.85
		_material.bounce = 0.04
	return _material

## Irregular blob: evenly spaced vertices at varying distances, so it reads as a
## lump of scrap rather than a die.
func _chunk_polygon(radius: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var count := rng.randi_range(5, 9)
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count) + rng.randf_range(-0.14, 0.14)
		points.append(Vector2(cos(angle), sin(angle)) * radius * rng.randf_range(0.68, 1.0))
	return points

## Anything from the catalog that can be dropped and grabbed: bodies, wheels and
## engines, the same pools the garage and the yard's scenery heap draw from.
func _random_part(rng: RandomNumberGenerator) -> PartData:
	var pool: Array[PartData] = []
	pool.append_array(PartDatabase.bodies)
	pool.append_array(PartDatabase.wheels)
	pool.append_array(PartDatabase.engines)
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]

func _instantiate(data: PartData) -> Node2D:
	if data == null or data.scene_path.is_empty():
		return null
	var scene := load(data.scene_path) as PackedScene
	if scene == null:
		push_warning("TrashHeap: part scene '%s' won't load." % data.scene_path)
		return null
	var instance: Node = scene.instantiate()
	if not (instance is Node2D):
		instance.free()
		return null
	return instance as Node2D
