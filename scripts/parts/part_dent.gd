class_name PartDent
extends RefCounted
## The pan factory's hammers: whacks a dent into a part, bending its art, its
## mount points and its collision outline, so a dented wheel really rolls
## lumpy and a bashed-in body really sits lower where it was hit.
##
## A hit pushes everything within the hammer's reach the way the hammer was
## swinging (the bench turns the part, so any side can be hit), most at the hit
## point and fading to nothing at the edge of the reach. Long edges near the
## hit get extra points first so a flat panel can cave in rather than just tilt.
##
## A part can only be squashed so far: it keeps at least MIN_SHAPE of the art
## and collision area it had before its first dent. The metal stiffens on the
## way there (each blow pushes less once it's below STIFF_FROM), and a blow that
## would take it under the floor just bounces off (`Result.TOO_FLAT`).
##
## The part stays in one piece: pieces that touched before the blow still touch
## after it. A piece the blow knocked loose is pulled back against the piece it
## was attached to, working out from the biggest piece (the main body).
##
## The result is baked into a ForgedLook on the part itself, the same way the
## scrap forge stores its mashes, so PartFactory shows the dents everywhere
## and they survive saving. A part that's been forged keeps its scrap and just
## gets dented on top.

enum Hammer { TACK, CLAW, SLEDGE }
enum Result { MISSED, DENTED, TOO_FLAT }

## How far a hammer reaches from where it lands, and how deep it pushes at the
## centre, in the part's own pixels for a part of REFERENCE_SIZE across.
const REACH := { Hammer.TACK: 10.0, Hammer.CLAW: 18.0, Hammer.SLEDGE: 32.0 }
const DEPTH := { Hammer.TACK: 2.5, Hammer.CLAW: 5.0, Hammer.SLEDGE: 9.0 }
const NAMES := { Hammer.TACK: "Tack Hammer", Hammer.CLAW: "Claw Hammer", Hammer.SLEDGE: "Sledgehammer" }
## A part this big across (the bathtub's diagonal) gets the hammer's plain
## reach; smaller or bigger parts scale it, within SIZE_SCALE.
const REFERENCE_SIZE := 170.0
const SIZE_SCALE := Vector2(0.6, 1.6)
## A hit that moves nothing more than this missed the part.
const MISS_DISTANCE := 0.5
## Pieces closer than this count as touching.
const TOUCH_GAP := 1.5
## How far a knocked-loose piece is pulled back into the piece it came off.
const REATTACH_OVERLAP := 2.0
const NAME_PREFIX := "Dented "
## The least of its first area a part can be squashed down to.
const MIN_SHAPE := 0.6
## Below this much of its first area the metal starts to stiffen, down to
## MIN_GIVE of a full blow right at the floor.
const STIFF_FROM := 0.85
const MIN_GIVE := 0.2

## Whacks `hammer` into `part` at `point`, swinging along `direction` (both in
## the part's own space, as PartFactory builds it). Changes `part` in place
## only when it returns DENTED; MISSED and TOO_FLAT leave it as it was.
static func hit(part: PartData, point: Vector2, hammer: Hammer, direction: Vector2 = Vector2.DOWN) -> Result:
	var root := PartFactory.instantiate(part)
	if root == null:
		return Result.MISSED
	var original := _original_area(part, root)
	var left := _shape_left(_area(root), original)
	if left <= MIN_SHAPE + 0.005:
		root.free()
		return Result.TOO_FLAT
	var give := clampf(inverse_lerp(MIN_SHAPE, STIFF_FROM, left), MIN_GIVE, 1.0)
	var reach := reach_for(art_size(root), hammer)
	var push: Vector2 = direction.normalized() * DEPTH[hammer] * _size_scale(art_size(root)) * give
	var polygons := _drawn_polygons(root)
	var links := _links(_outlines(polygons, root))
	var moved := false
	for polygon_node in _polygons(root):
		moved = _dent_polygon(polygon_node, root, point, reach, push) or moved
	if moved:
		_keep_together(polygons, root, links)
	for marker in root.find_children("*", "Marker2D", true, false):
		var to_root := PartForge.relative_transform(marker.get_parent(), root)
		var at_root: Vector2 = to_root * (marker as Marker2D).position
		(marker as Marker2D).position = to_root.affine_inverse() * (at_root + push * _falloff(at_root, point, reach))
	var collision := _root_collision(root)
	if collision != null:
		var outline := _dented(collision.polygon, point, reach, push, true)
		if PolygonMorph.is_drawable(outline):
			collision.polygon = outline
	if not moved:
		root.free()
		return Result.MISSED
	if _shape_left(_area(root), original) < MIN_SHAPE:
		root.free()
		return Result.TOO_FLAT
	_bake(part, root, collision, original)
	root.free()
	return Result.DENTED

## How much of its first area `part` still has (1 for a part never dented;
## it can go over 1 when blows push metal outward).
static func shape_left(part: PartData) -> float:
	var root := PartFactory.instantiate(part)
	if root == null:
		return 1.0
	var left := _shape_left(_area(root), _original_area(part, root))
	root.free()
	return left

## How squashed the part is: the lesser of its art and collision areas, each
## as a share of what it had before its first dent.
static func _shape_left(area: Vector2, original: Vector2) -> float:
	var art := area.x / original.x if original.x > 0.0 else 1.0
	var body := area.y / original.y if original.y > 0.0 else 1.0
	return minf(art, body)

## The art and collision areas the part had before its first dent: stored on
## its look once dented, otherwise what it has now.
static func _original_area(part: PartData, root: Node) -> Vector2:
	if part.forge != null and part.forge.dents > 0 and part.forge.original_art_area > 0.0:
		return Vector2(part.forge.original_art_area, part.forge.original_collision_area)
	return _area(root)

## (total area of the drawn pieces, area of the collision outline) in the
## root's space. Overlapping pieces count twice; only the ratio matters.
static func _area(root: Node) -> Vector2:
	var art := 0.0
	for outline in _outlines(_drawn_polygons(root), root):
		art += absf(PartForge.signed_area(outline))
	var collision := _root_collision(root)
	var body := absf(PartForge.signed_area(collision.polygon)) if collision != null else 0.0
	return Vector2(art, body)

## How far `hammer` reaches on a part whose art is `art_diagonal` across.
static func reach_for(art_diagonal: float, hammer: Hammer) -> float:
	return REACH[hammer] * _size_scale(art_diagonal)

static func _size_scale(art_diagonal: float) -> float:
	return clampf(art_diagonal / REFERENCE_SIZE, SIZE_SCALE.x, SIZE_SCALE.y)

## What the bench turns the part around: a wheel's axle, or the middle of the
## art for anything else.
static func art_center(root: Node, part: PartData) -> Vector2:
	if part.category == PartData.Category.WHEEL:
		return Vector2.ZERO
	return PartForge.bounds_of(_art_points(root)).get_center()

## The diagonal of the part's art, in its own pixels.
static func art_size(root: Node) -> float:
	return PartForge.bounds_of(_art_points(root)).size.length()

static func _art_points(root: Node) -> PackedVector2Array:
	var points := PackedVector2Array()
	for piece in PartForge.harvest(root, root):
		points.append_array(piece.points)
	return points

## How much of the push a point at `at` gets: all of it right under the
## hammer, easing off to none at the edge of its reach.
static func _falloff(at: Vector2, point: Vector2, reach: float) -> float:
	var t := at.distance_to(point) / reach
	if t >= 1.0:
		return 0.0
	var soft := 1.0 - t * t
	return soft * soft

## Dents one Polygon2D, in the root's space. Returns whether it moved.
static func _dent_polygon(polygon_node: Polygon2D, root: Node, point: Vector2, reach: float, push: Vector2) -> bool:
	var to_root := PartForge.relative_transform(polygon_node, root)
	var from_root := to_root.affine_inverse()
	var outline := PackedVector2Array()
	for vertex in polygon_node.polygon:
		outline.append(to_root * (vertex + polygon_node.offset))
	# Rings and other multi-part polygons index their vertices, so they can't
	# take extra points; they just bend at the corners they have.
	var can_grow := polygon_node.polygons.is_empty() and polygon_node.uv.is_empty()
	var bent := _dented(outline, point, reach, push, can_grow)
	if bent == outline:
		return false
	if polygon_node.polygons.is_empty() and not PolygonMorph.is_drawable(bent):
		return false
	for i in bent.size():
		bent[i] = from_root * bent[i] - polygon_node.offset
	polygon_node.polygon = bent
	return true

## `outline` with the dent in. With `can_grow`, edges passing near the hit
## get extra points first so they can bend in the middle.
static func _dented(outline: PackedVector2Array, point: Vector2, reach: float, push: Vector2, can_grow: bool) -> PackedVector2Array:
	var points := _densify_near(outline, point, reach) if can_grow else outline
	var bent := PackedVector2Array()
	var moved := false
	for vertex in points:
		var shift := push * _falloff(vertex, point, reach)
		moved = moved or shift.length() > MISS_DISTANCE
		bent.append(vertex + shift)
	return bent if moved else outline

## Extra points along edges that pass within `reach` of `point`, a few per
## reach so the dent comes out as a few chunky facets, not a smooth curve.
static func _densify_near(outline: PackedVector2Array, point: Vector2, reach: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var step := reach / 2.0
	for i in outline.size():
		var from := outline[i]
		var to := outline[(i + 1) % outline.size()]
		out.append(from)
		var nearest := Geometry2D.get_closest_point_to_segment(point, from, to)
		if nearest.distance_to(point) >= reach:
			continue
		var cuts := clampi(int(from.distance_to(to) / step), 1, 8)
		for k in range(1, cuts):
			var along := from.lerp(to, float(k) / cuts)
			if along.distance_to(point) < reach:
				out.append(along)
	return out

# --- Keeping it in one piece -------------------------------------------------------

## The polygons that actually show (hidden and see-through ones don't hold
## anything together).
static func _drawn_polygons(root: Node) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	for polygon_node in _polygons(root):
		if polygon_node.color.a >= 0.05 and polygon_node.polygon.size() >= 3 and _is_drawn(polygon_node, root):
			out.append(polygon_node)
	return out

static func _is_drawn(node: Node, root: Node) -> bool:
	var current := node
	while current != null:
		if current is CanvasItem and not (current as CanvasItem).visible:
			return false
		if current == root:
			return true
		current = current.get_parent()
	return true

## Each polygon's outline in the root's space. A ring (outer and inner loop in
## one polygon) is taken as its hull.
static func _outlines(polygons: Array[Polygon2D], root: Node) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for polygon_node in polygons:
		var to_root := PartForge.relative_transform(polygon_node, root)
		var outline := PackedVector2Array()
		for vertex in polygon_node.polygon:
			outline.append(to_root * (vertex + polygon_node.offset))
		if not polygon_node.polygons.is_empty() or not PolygonMorph.is_drawable(outline):
			outline = PartForge.hull(outline)
		out.append(outline)
	return out

## Which pieces touch which, as a list of neighbour indices per piece.
static func _links(outlines: Array[PackedVector2Array]) -> Array[PackedInt32Array]:
	var links: Array[PackedInt32Array] = []
	links.resize(outlines.size())
	for i in outlines.size():
		for j in range(i + 1, outlines.size()):
			if _touching(outlines[i], outlines[j]):
				links[i].append(j)
				links[j].append(i)
	return links

static func _touching(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	if not PartForge.bounds_of(a).grow(TOUCH_GAP).intersects(PartForge.bounds_of(b).grow(TOUCH_GAP)):
		return false
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return true
	return _gap(a, b).length() <= TOUCH_GAP

## The shortest step that takes outline `a` onto outline `b`.
static func _gap(a: PackedVector2Array, b: PackedVector2Array) -> Vector2:
	var best := Vector2.INF
	for pair in [[a, b, 1.0], [b, a, -1.0]]:
		var from: PackedVector2Array = pair[0]
		var to: PackedVector2Array = pair[1]
		for point in from:
			for k in to.size():
				var step: Vector2 = (Geometry2D.get_closest_point_to_segment(point, to[k], to[(k + 1) % to.size()]) - point) * pair[2]
				if step.length_squared() < best.length_squared():
					best = step
	return best

## Walks out from the biggest piece over the pieces that touched before the
## blow; any piece that no longer touches a piece already settled gets slid
## back onto the one it hung off.
static func _keep_together(polygons: Array[Polygon2D], root: Node, links: Array[PackedInt32Array]) -> void:
	var outlines := _outlines(polygons, root)
	var settled := {}
	var queue: Array[int] = []
	# Biggest piece first. Every cluster that was separate to begin with (a
	# horse's loose mane, say) gets walked from its own biggest piece after.
	var order := range(outlines.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return absf(PartForge.signed_area(outlines[a])) > absf(PartForge.signed_area(outlines[b])))
	for start: int in order:
		if settled.has(start):
			continue
		settled[start] = true
		queue.append(start)
		while not queue.is_empty():
			var current: int = queue.pop_front()
			for next in links[current]:
				if settled.has(next):
					continue
				var holds := false
				for neighbour in links[next]:
					if settled.has(neighbour) and _touching(outlines[next], outlines[neighbour]):
						holds = true
						break
				if not holds:
					var step := _gap(outlines[next], outlines[current])
					step += step.normalized() * REATTACH_OVERLAP
					_slide(polygons[next], root, step)
					var slid := outlines[next]
					for k in slid.size():
						slid[k] += step
					outlines[next] = slid
				settled[next] = true
				queue.append(next)

## Moves a polygon by `step` in the root's space.
static func _slide(polygon_node: Polygon2D, root: Node, step: Vector2) -> void:
	var local_step := PartForge.relative_transform(polygon_node, root).affine_inverse().basis_xform(step)
	var points := polygon_node.polygon
	for i in points.size():
		points[i] += local_step
	polygon_node.polygon = points

static func _polygons(root: Node) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	if root is Polygon2D:
		out.append(root)
	for node in root.find_children("*", "Polygon2D", true, false):
		out.append(node as Polygon2D)
	return out

static func _root_collision(root: Node) -> CollisionPolygon2D:
	for child in root.get_children():
		if child is CollisionPolygon2D:
			return child
	return null

## Writes the dented instance into a fresh ForgedLook on `part`. Every polygon
## becomes an override (scrap from an earlier forging stays scrap, on the
## anchor the forge put it on), every marker keeps its new spot, and the
## collision outline is stored. The first dent gives the part its own id, so
## it no longer stacks with clean copies in the garage.
static func _bake(part: PartData, root: Node, collision: CollisionPolygon2D, original: Vector2) -> void:
	var old := part.forge
	var look := ForgedLook.new()
	look.base_part_id = part.catalog_id()
	look.base_display_name = old.base_display_name if old != null else part.display_name
	# Where the scrap forge would graft onto this part later (a horse's torso).
	look.anchor_path = old.anchor_path if old != null else root.get_path_to(PartForge.find_anchor(root, part))
	look.dents = (old.dents if old != null else 0) + 1
	look.original_art_area = original.x
	look.original_collision_area = original.y
	for polygon_node in _polygons(root):
		var parent := polygon_node.get_parent()
		if parent != null and parent.name == ForgedLook.FRONT_LAYER:
			look.front_polygons.append(polygon_node.polygon)
			look.front_colors.append(polygon_node.color)
		elif parent != null and parent.name == ForgedLook.BACK_LAYER:
			look.back_polygons.append(polygon_node.polygon)
			look.back_colors.append(polygon_node.color)
		else:
			look.override_paths.append(String(root.get_path_to(polygon_node)))
			look.override_polygons.append(polygon_node.polygon)
			look.override_colors.append(polygon_node.color)
	for marker in root.find_children("*", "Marker2D", true, false):
		look.marker_paths.append(String(root.get_path_to(marker)))
		look.marker_positions.append((marker as Marker2D).position)
	if collision != null:
		look.collision_polygon = collision.polygon
	if old == null:
		part.id = StringName("dented_%08x%08x" % [randi(), Time.get_ticks_usec() & 0xffffffff])
	if look.dents == 1 and not part.display_name.begins_with(NAME_PREFIX):
		part.display_name = NAME_PREFIX + part.display_name
	part.forge = look
