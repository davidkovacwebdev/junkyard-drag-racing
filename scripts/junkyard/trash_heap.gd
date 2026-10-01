class_name TrashHeap
extends Node2D
## A real heap of junk, for the crane to dig in.
##
## Unlike the calm, art-directed pile in the yard (see junkyard_pile.gd, which
## has to be placid because the player drives through it), this one is dumped:
## every piece is a real RigidBody2D with gravity on, dropped in from above the
## frame and left to fall, roll and stack into a mound on the pen floor.
##
## Every piece is a real car part, and the heap is layered so the player can
## read it: tier-2 parts are tipped in first and make the bottom, tier-1 parts
## are let go once those have landed and lie on top in plain sight. Aiming at
## the surface gets you something you can see; the better stuff means digging
## through it.
##
## The crane's claw is a pair of real bodies in the same physics world, so it
## shoves these parts aside and scoops them up like any other collision; the
## heap only answers what a piece is (`part_of()`) and lets go of it (`take()`).
## Each piece carries its own PartData, and is exactly the part the player ends
## up owning.
##
## Origin is the pen floor, +y down, art extends upward, so it Y-sorts against
## the crane like any other prop.

## How wide the load is tipped out, each side of this node's origin. Keep it
## comfortably inside the pen walls: everything dropped lands where it falls.
@export var drop_half_width: float = 260.0
## Pull the pin from this far up (the junk starts off-screen and rains in).
@export var drop_height: float = 760.0
## Clear air left between one piece and the next in the drop queue. Each piece
## starts a whole piece-height above the last, so none of them spawn inside
## each other — overlapping bodies shove apart hard enough to fire a part out
## of the pen.
@export var drop_gap: float = 12.0
## How many tier-2 parts make up the bottom layer. Tipped in first, so they
## end up under everything else: the prize you have to dig for.
@export var deep_count: int = 7
## How many tier-1 parts lie on top. Queued above the bottom layer, so the
## surface of the heap is all junk-grade and in plain sight.
@export var top_count: int = 7
## Extra air between the bottom layer's queue and the top layer's, so the top
## lands on a bottom that has already come to rest instead of mixing into it.
@export var layer_gap: float = 500.0
## How far below the floor a piece has to be to count as lost through it.
## Some parts' collision shapes are fine jagged stars (the saw blade) that, at
## heap scale, break into slivers thin enough to slip through the floor under a
## heavy landing. A lost piece is dropped back on the heap rather than gone.
@export var lost_depth: float = 300.0
## Fixed seed = the same heap every visit; 0 = tipped fresh every time.
@export var heap_seed: int = 0

const ITEM_GROUP := &"heap_item"

## Everything lying in the heap, in the order it was tipped in.
var _items: Array[Node2D] = []
## Friction/bounce for the junk, shared by every piece.
var _material: PhysicsMaterial = null

func _ready() -> void:
	var rng := _rng()
	# Height the next piece starts at: climbs as the queue grows (-y is up).
	var cursor := -drop_height
	for i in deep_count:
		cursor = _spawn_part(rng, 2, cursor)
	cursor -= layer_gap
	for i in top_count:
		cursor = _spawn_part(rng, 1, cursor)

func _physics_process(_delta: float) -> void:
	for item in _items:
		if not is_instance_valid(item) or item.position.y < lost_depth:
			continue
		var body := item as RigidBody2D
		if body == null or body.freeze:
			continue
		var at := to_global(Vector2(randf_range(-drop_half_width, drop_half_width) * 0.5, -drop_height))
		PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(body.rotation, at))
		body.global_position = at
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0

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

## Scrap a piece is worth, from its `scrap` meta. The heap is all parts now and
## a part is worth no scrap — it's the part itself the player keeps — but a
## piece tagged by hand still weighs in.
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

## A real part scene of `tier` from the same catalog the garage browses,
## shrunk to the size the world's cars wear it at (PartScale), so the heap is
## in scale with the claw. Its lowest point starts at `cursor`; returns the
## height the next piece in the queue starts at, clear above this one.
func _spawn_part(rng: RandomNumberGenerator, tier: int, cursor: float) -> float:
	var body := _build_part(rng, tier)
	if body == null:
		return cursor
	# The diagonal, not the height: the piece is tipped in at a random angle.
	var size := PartScale.measure_bounds(body).size.length()
	var at := Vector2(rng.randf_range(-drop_half_width, drop_half_width), cursor - size * 0.5)
	_tip(body, at)
	body.rotation = rng.randf_range(0.0, TAU)
	return cursor - size - drop_gap

## One loose part, ready to be tipped in, or null if the catalog couldn't supply
## one.
##
## Rolls again rather than giving up when a pick turns out to be unusable, so
## the layer counts are what actually land in the heap. Two picks need rejecting: a
## paddle wheel, which forces its own rotation to a fixed angle every physics
## tick even at rest (car_paddle.gd's "parked" branch) and so never tumbles
## naturally while falling and settling — reads as the piece rigidly shoving
## through the pile instead of landing in it; and a part whose art measures to
## nothing, which has no shape to collide with.
func _build_part(rng: RandomNumberGenerator, tier: int) -> RigidBody2D:
	for attempt in 8:
		var node := _instantiate(_random_part(rng, tier))
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
	body.name = "Part%d" % _items.size()
	body.mass = clampf(body.mass, 1.0, 30.0)
	body.can_sleep = true
	body.linear_damp = 0.3
	body.angular_damp = 0.5
	# The top of the queue lands fast, and a small part under a big one can be
	# driven straight through the floor between two ticks without this.
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.add_to_group(ITEM_GROUP)
	_items.append(body)

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

## Anything of `tier` from the catalog that can be dropped and grabbed:
## bodies, wheels and engines, the same pools the garage and the yard's scenery
## heap draw from. Falls back to the whole pool if nothing is that tier.
func _random_part(rng: RandomNumberGenerator, tier: int) -> PartData:
	var pool: Array[PartData] = []
	pool.append_array(PartDatabase.bodies)
	pool.append_array(PartDatabase.wheels)
	pool.append_array(PartDatabase.junk_engines)
	pool.append_array(PartDatabase.junk_accessories)
	var matching := pool.filter(func(part: PartData) -> bool: return part.tier == tier)
	if not matching.is_empty():
		pool.assign(matching)
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]

func _instantiate(data: PartData) -> Node2D:
	return PartFactory.instantiate(data)
