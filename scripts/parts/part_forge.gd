class_name PartForge
extends RefCounted
## The scrap forge's smelter: melts two or three parts into one new part.
##
## What comes out is rolled from what goes in. Every ingredient pulls toward its
## own category by its heft (how much art it has, and how heavy it is), so a
## horse and a TV wheel usually make an engine but sometimes a wheel. The
## heaviest ingredient of the rolled category becomes the base: its scene keeps
## supplying the script, animation, mounts and physics, so a forged horse still
## trots and a forged pogo still bounces.
##
## The look is a real blend of the ingredients' polygons, one donor at a time:
##   1. Both drawings are fitted into one frame whose proportions sit between
##      theirs, and each is bent radially toward a silhouette halfway between
##      the two (see PolygonMorph.Envelope). A TV wheel sprouts the horse's
##      legs and neck while the horse gets boxy.
##   2. Every base polygon is paired with the donor polygon closest to it in
##      place and size, and the two are averaged vertex by vertex, colours too.
##   3. Donor pieces nobody paired with are fused in, big ones behind the base
##      and small details over it.
## Only polygon shapes change, never the base's node tree, so its animation
## carries on; its mount markers and collision are bent along with the art.
## The result is baked into a ForgedLook.

const MIN_INGREDIENTS := 2
const MAX_INGREDIENTS := 3
const MAX_FRONT_SCRAP := 24
const MAX_BACK_SCRAP := 12
const MAX_NAME_LETTERS := 12
## Donor pieces smaller than this share of the donor's art aren't fused in.
const MIN_LEFTOVER_SHARE := 0.02
## Fused donor pieces bigger than this share of the part go behind it.
const BACKDROP_SHARE := 0.2
const MAX_LEFTOVERS := 6
## How much a donor's shape comes through, from a featherweight donor to one
## that outweighs the base; later donors in a three-part mash pull less.
const BLEND_RANGE := Vector2(0.35, 0.65)
const LATER_DONOR_PULL := 0.7
## Share of the blend amount used when averaging paired polygons' shapes and
## colours. Lower keeps the base's own pieces (legs, wheels) readable.
const SHAPE_PULL := 0.6
const COLOR_PULL := 0.7

const _GENERIC_WORDS: Array[String] = ["wheel", "engine", "motor", "body", "tire", "tyre", "the", "old", "car"]
const _CAR_WHEEL_SCRIPT := preload("res://scripts/car/car_wheel.gd")

class Piece:
	var points: PackedVector2Array
	var color: Color

	func _init(piece_points: PackedVector2Array, piece_color: Color) -> void:
		points = piece_points
		color = piece_color

	func area() -> float:
		return absf(PartForge.signed_area(points))

## Maps a point of one drawing into the blended shape: fit into the shared
## frame, bend toward the blended silhouette, then shift (an engine's mounting
## point has to stay put).
class Warp:
	var frame: Transform2D
	var from: PolygonMorph.Envelope
	var to: PolygonMorph.Envelope
	var shift := Vector2.ZERO

	func apply(point: Vector2) -> Vector2:
		return PolygonMorph.bend(frame * point, from, to) + shift

static var _heft_cache: Dictionary = {}

# --- Rolling the outcome ---------------------------------------------------------

## Chance of each category coming out, as {PartData.Category: 0..1}.
static func category_odds(ingredients: Array[PartData]) -> Dictionary:
	var odds := {}
	var total := 0.0
	for part in ingredients:
		var heft := _heft(part)
		odds[part.category] = float(odds.get(part.category, 0.0)) + heft
		total += heft
	for category in odds:
		odds[category] = float(odds[category]) / total if total > 0.0 else 1.0 / odds.size()
	return odds

static func can_forge(ingredients: Array[PartData]) -> bool:
	return ingredients.size() >= MIN_INGREDIENTS and ingredients.size() <= MAX_INGREDIENTS

## Melt `ingredients` into one new part. The ingredients themselves are left
## untouched; taking them out of the player's stash is the caller's job.
static func forge(ingredients: Array[PartData], rng: RandomNumberGenerator) -> PartData:
	var category := _roll_category(category_odds(ingredients), rng)
	var base := _pick_base(ingredients, category)
	var donors: Array[PartData] = []
	for part in ingredients:
		if part != base:
			donors.append(part)
	var result: PartData = base.duplicate()
	_mix_stats(result, ingredients, category, rng)
	result.forge = _mash_look(base, donors, category, rng)
	result.id = StringName("forged_%08x%08x" % [rng.randi(), Time.get_ticks_usec() & 0xffffffff])
	result.display_name = _forged_name(base, donors, rng)
	result.tier = PartDatabase.tier_for(result)
	return result

static func _roll_category(odds: Dictionary, rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var reached := 0.0
	for category in odds:
		reached += float(odds[category])
		if roll <= reached:
			return category
	return odds.keys().back()

static func _pick_base(ingredients: Array[PartData], category: int) -> PartData:
	var base: PartData = null
	for part in ingredients:
		if part.category == category and (base == null or _heft(part) > _heft(base)):
			base = part
	return base

## How hard a part pulls the outcome toward its own category: the size of its
## silhouette, weighted by how heavy it is.
static func _heft(part: PartData) -> float:
	if _heft_cache.has(part.id):
		return _heft_cache[part.id]
	var instance := PartFactory.instantiate(part)
	var area := 0.0
	if instance != null:
		area = absf(signed_area(hull(_points_of(harvest(instance, instance)))))
		instance.free()
	var heft := sqrt(area) * (0.5 + part.mass / PartData.MASS_RANGE.y)
	_heft_cache[part.id] = heft
	return heft

# --- Stats -----------------------------------------------------------------------

## Averages the ingredients (the ones of the outcome's own category count
## double), then adds a bonus for every extra part melted in and a roll of luck.
static func _mix_stats(result: PartData, ingredients: Array[PartData], category: int, rng: RandomNumberGenerator) -> void:
	var extra := ingredients.size() - 1
	var weight_total := 0.0
	var durability := 0.0
	var speed := 0.0
	var mass := 0.0
	for part in ingredients:
		var weight := 2.0 if part.category == category else 1.0
		weight_total += weight
		durability += part.durability * weight
		speed += part.speed * weight
		mass += part.mass * weight
	result.durability = clampf(durability / weight_total * (1.0 + 0.12 * extra) * rng.randf_range(0.85, 1.2),
			PartData.DURABILITY_RANGE.x * 0.5, PartData.DURABILITY_RANGE.y * 1.2)
	result.speed = clampf(speed / weight_total * (1.0 + 0.06 * extra) * rng.randf_range(0.85, 1.2),
			PartData.SPEED_RANGE.x * 0.5, PartData.SPEED_RANGE.y * 1.1)
	result.mass = clampf(mass / weight_total * rng.randf_range(0.8, 1.15),
			PartData.MASS_RANGE.x * 0.5, PartData.MASS_RANGE.y * 1.2)
	var same := ingredients.filter(func(part: PartData) -> bool: return part.category == category)
	if result is EnginePartData:
		var power := 0.0
		for engine: EnginePartData in same:
			power += engine.power
		var engine_result := result as EnginePartData
		engine_result.power = clampf(power / same.size() * (1.0 + 0.08 * extra) * rng.randf_range(0.9, 1.12),
				0.5, _max_catalog_power())
		# By convention an engine's speed rating is its power.
		engine_result.speed = engine_result.power
	elif result is WheelPartData:
		var absorption := 0.0
		for wheel: WheelPartData in same:
			absorption += wheel.absorption
		var wheel_result := result as WheelPartData
		wheel_result.absorption = clampf(absorption / same.size() + 0.04 * extra * rng.randf(), 0.0, 0.9)

static func _max_catalog_power() -> float:
	var best := 1.0
	for engine in PartDatabase.engines:
		best = maxf(best, engine.power)
	return best

# --- Names -----------------------------------------------------------------------

## Syllables of the parts smushed into one word, donors first so the base's
## ending reads as the noun: horse + Television -> "Horvision". The base's
## "Wheel"/"Engine" word is kept so it's still clear what the part is.
static func _forged_name(base: PartData, donors: Array[PartData], rng: RandomNumberGenerator) -> String:
	var words: Array[String] = []
	for donor in donors:
		words.append(_name_root(donor))
	words.append(_name_root(base))
	var mashed := _mash_syllables(words, rng, false)
	if mashed.length() > MAX_NAME_LETTERS:
		mashed = _mash_syllables(words, rng, true)
	mashed = mashed.left(1).to_upper() + mashed.substr(1)
	var kind := _generic_word(base)
	return mashed if kind.is_empty() else "%s %s" % [mashed, kind]

## The front syllables of every word but the last, then the tail of the last.
## `short` keeps just one syllable from each front word and the last word's final one.
static func _mash_syllables(words: Array[String], rng: RandomNumberGenerator, short: bool) -> String:
	var mashed := ""
	for i in words.size():
		var syllables := syllables_of(words[i])
		var most := maxi(1, syllables.size() - 1)
		if i < words.size() - 1:
			mashed += "".join(syllables.slice(0, 1 if short else rng.randi_range(1, most)))
		elif syllables.size() == 1:
			mashed += syllables[0]
		else:
			mashed += "".join(syllables.slice(syllables.size() - 1 if short else rng.randi_range(1, most)))
	return mashed

## A forged part is named by its own mashed word, so re-forging keeps
## smushing: "Horvision" + fridge -> "Fridvision".
static func _name_root(part: PartData) -> String:
	if part.forge != null:
		return part.display_name.get_slice(" ", 0)
	return nickname(part)

static func _generic_word(part: PartData) -> String:
	var full_name := part.forge.base_display_name if part.forge != null else part.display_name
	for word in full_name.split(" ", false):
		if _GENERIC_WORDS.has(word.to_lower()) and word.length() > 3:
			return word.capitalize()
	return ""

## Rough English syllables: consonants up to a vowel run, plus one trailing
## consonant when a cluster follows ("Television" -> te/le/vi/sion,
## "Horse" -> hor/se).
static func syllables_of(word: String) -> PackedStringArray:
	var regex := RegEx.create_from_string("[^aeiouy]*[aeiouy]+(?:[^aeiouy]+$|[^aeiouy](?=[^aeiouy]))?")
	var letters := RegEx.create_from_string("[^a-z]").sub(word.to_lower(), "", true)
	var syllables := PackedStringArray()
	for found in regex.search_all(letters):
		syllables.append(found.get_string())
	if syllables.is_empty():
		syllables.append(letters)
	return syllables

## The word that says what a part is: the longest one that isn't just
## "Wheel" or "Engine" ("Lawn Mower Engine" -> "Mower").
static func nickname(part: PartData) -> String:
	var full_name := part.forge.base_display_name if part.forge != null else part.display_name
	var best := ""
	for word in full_name.split(" ", false):
		if _GENERIC_WORDS.has(word.to_lower()):
			continue
		if word.length() > best.length():
			best = word
	return best if not best.is_empty() else full_name.get_slice(" ", 0)

# --- The mash --------------------------------------------------------------------

static func _mash_look(base: PartData, donors: Array[PartData], category: int, rng: RandomNumberGenerator) -> ForgedLook:
	var root := PartFactory.instantiate(base)
	var anchor := _find_anchor(root, base)
	var collision: CollisionPolygon2D = null
	var rolls_on_art: bool = category == PartData.Category.WHEEL and root.get_script() == _CAR_WHEEL_SCRIPT
	if anchor == root and (rolls_on_art or category == PartData.Category.BODY):
		collision = _root_collision(root)
	for i in donors.size():
		var instance := PartFactory.instantiate(donors[i])
		if instance == null:
			continue
		var donor_pieces := harvest(instance, instance)
		instance.free()
		if donor_pieces.is_empty():
			continue
		var share := _heft(donors[i]) / maxf(_heft(base) + _heft(donors[i]), 0.001)
		var amount := clampf(lerpf(BLEND_RANGE.x, BLEND_RANGE.y, share) + rng.randf_range(-0.08, 0.08), 0.25, 0.75)
		if i > 0:
			amount *= LATER_DONOR_PULL
		_blend_in(root, anchor, donor_pieces, category, amount, collision, rng)

	var look := ForgedLook.new()
	look.base_part_id = base.catalog_id()
	look.base_display_name = base.forge.base_display_name if base.forge != null else base.display_name
	look.anchor_path = root.get_path_to(anchor)
	_bake(root, anchor, look)
	if collision != null:
		look.collision_polygon = collision.polygon
	root.free()
	return look

## One donor blended into the live base instance (see the class notes).
static func _blend_in(root: Node, anchor: Node, donor_pieces: Array[Piece], category: int, amount: float,
		collision: CollisionPolygon2D, rng: RandomNumberGenerator) -> void:
	var base_pieces := harvest(anchor, anchor)
	var base_bounds := bounds_of(_points_of(base_pieces))
	var donor_bounds := bounds_of(_points_of(donor_pieces))
	if base_bounds.size.x <= 0.0 or base_bounds.size.y <= 0.0 or donor_bounds.size.x <= 0.0 or donor_bounds.size.y <= 0.0:
		return
	# Wheels blend around their axle so they still turn on it.
	var center := Vector2.ZERO if category == PartData.Category.WHEEL else base_bounds.get_center()
	var aspect_pull := amount * (0.3 if category == PartData.Category.WHEEL else 0.7)
	var aspect := exp(lerpf(log(base_bounds.size.aspect()), log(donor_bounds.size.aspect()), aspect_pull))
	var area := base_bounds.get_area()
	var frame_size := Vector2(sqrt(area * aspect), sqrt(area / aspect))
	var base_scale := frame_size / base_bounds.size
	var frame_center := center + (base_bounds.get_center() - center) * base_scale
	var donor_scale := minf(frame_size.x / donor_bounds.size.x, frame_size.y / donor_bounds.size.y)

	var base_warp := Warp.new()
	base_warp.frame = Transform2D(0.0, base_scale, 0.0, center) * Transform2D(0.0, -center)
	var donor_warp := Warp.new()
	donor_warp.frame = Transform2D(0.0, Vector2.ONE * donor_scale, 0.0, frame_center) \
			* Transform2D(0.0, -donor_bounds.get_center())
	base_warp.from = PolygonMorph.Envelope.new(_outlines(base_pieces, base_warp.frame), center)
	donor_warp.from = PolygonMorph.Envelope.new(_outlines(donor_pieces, donor_warp.frame), center)
	var blended := PolygonMorph.blend_envelopes(base_warp.from, donor_warp.from, amount)
	base_warp.to = blended
	donor_warp.to = blended
	if category == PartData.Category.ENGINE and anchor == root:
		base_warp.shift = -base_warp.apply(Vector2.ZERO)
		donor_warp.shift = base_warp.shift

	_warp_base(anchor, base_warp, collision)
	var donor_shapes: Array[Piece] = []
	for piece in donor_pieces:
		var bent := PackedVector2Array()
		for point in piece.points:
			bent.append(donor_warp.apply(point))
		donor_shapes.append(Piece.new(bent, piece.color))
	var used := _average_pieces(root, anchor, donor_shapes, frame_size.length(), amount, rng)
	_fuse_leftovers(anchor, donor_shapes, used, _palette(base_pieces)[0], amount, frame_size.x * frame_size.y)

static func _outlines(pieces: Array[Piece], frame: Transform2D) -> Array:
	var out: Array = []
	for piece in pieces:
		out.append(frame * piece.points)
	return out

## Bends every polygon, mount marker and the collision shape of the base.
static func _warp_base(anchor: Node, warp: Warp, collision: CollisionPolygon2D) -> void:
	for polygon_node in _polygons_under(anchor):
		var to_anchor := relative_transform(polygon_node, anchor)
		var from_anchor := to_anchor.affine_inverse()
		var points := polygon_node.polygon
		for i in points.size():
			points[i] = from_anchor * warp.apply(to_anchor * (points[i] + polygon_node.offset)) - polygon_node.offset
		polygon_node.polygon = points
	for node in _nodes_under(anchor):
		if node is Marker2D:
			var marker := node as Marker2D
			var parent_to_anchor := relative_transform(marker.get_parent(), anchor)
			marker.position = parent_to_anchor.affine_inverse() * warp.apply(parent_to_anchor * marker.position)
	if collision != null:
		var outline := _densify(collision.polygon, bounds_of(collision.polygon).size.length() / 24.0)
		for i in outline.size():
			outline[i] = warp.apply(outline[i])
		if PolygonMorph.is_drawable(outline):
			collision.polygon = outline

## Pairs every base polygon with the donor shape closest to it in place and
## size, and averages the two. Returns which donor shapes got a partner.
static func _average_pieces(root: Node, anchor: Node, donor_shapes: Array[Piece], frame_diagonal: float,
		amount: float, rng: RandomNumberGenerator) -> Dictionary:
	var base_nodes: Array[Polygon2D] = []
	var base_points: Array[PackedVector2Array] = []
	for polygon_node in _polygons_under(anchor):
		if ForgedLook.is_scrap_layer(polygon_node.get_parent()) or not polygon_node.polygons.is_empty() \
				or polygon_node.polygon.size() < 3 or polygon_node.color.a < 0.05 or not _is_drawn(polygon_node, root):
			continue
		var to_anchor := relative_transform(polygon_node, anchor)
		var points := PackedVector2Array()
		for point in polygon_node.polygon:
			points.append(to_anchor * (point + polygon_node.offset))
		if absf(signed_area(points)) < 0.5:
			continue
		base_nodes.append(polygon_node)
		base_points.append(points)

	var costs: Array[Array] = []
	for b in base_points.size():
		for d in donor_shapes.size():
			costs.append([_pair_cost(base_points[b], donor_shapes[d].points, frame_diagonal), b, d])
	costs.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var partner := {}
	var used := {}
	for entry in costs:
		if not partner.has(entry[1]) and not used.has(entry[2]):
			partner[entry[1]] = entry[2]
			used[entry[2]] = true
	# More base pieces than donor pieces: the rest share their best match.
	for entry in costs:
		if not partner.has(entry[1]):
			partner[entry[1]] = entry[2]

	for b in base_nodes.size():
		if not partner.has(b):
			continue
		var donor: Piece = donor_shapes[partner[b]]
		var pull := clampf(amount * SHAPE_PULL * rng.randf_range(0.75, 1.15), 0.0, 0.7)
		var mixed := PolygonMorph.blend(base_points[b], donor.points, pull, pull * 0.3)
		if not PolygonMorph.is_drawable(mixed):
			pull *= 0.5
			mixed = PolygonMorph.blend(base_points[b], donor.points, pull, pull * 0.3)
		if not PolygonMorph.is_drawable(mixed):
			continue
		var polygon_node := base_nodes[b]
		var from_anchor := relative_transform(polygon_node, anchor).affine_inverse()
		for i in mixed.size():
			mixed[i] = from_anchor * mixed[i] - polygon_node.offset
		polygon_node.polygon = mixed
		polygon_node.color = _mix_paint(polygon_node.color, donor.color, amount * COLOR_PULL * rng.randf_range(0.6, 1.0))
	return used

static func _pair_cost(shape: PackedVector2Array, other: PackedVector2Array, frame_diagonal: float) -> float:
	var distance := PolygonMorph.centroid(shape).distance_to(PolygonMorph.centroid(other)) / maxf(frame_diagonal, 1.0)
	var size_gap := absf(log(maxf(absf(signed_area(shape)), 0.5) / maxf(absf(signed_area(other)), 0.5)))
	return distance + 0.35 * size_gap

## The donor's own details (every piece smaller than BACKDROP_SHARE of the
## part) are fused over the blend so what it was still reads: a TV's screen and
## knobs end up in the horse's barrel. Big donor pieces nobody paired with go
## behind it. They land in the base's scrap layers, where the next donor (and
## the bake) pick them up like any other art.
static func _fuse_leftovers(anchor: Node, donor_shapes: Array[Piece], used: Dictionary, base_paint: Color,
		amount: float, part_area: float) -> void:
	var total := 0.0
	for piece in donor_shapes:
		total += piece.area()
	var front: Array[Piece] = []
	var back: Array[Piece] = []
	for d in donor_shapes.size():
		var piece := donor_shapes[d]
		if piece.area() < total * MIN_LEFTOVER_SHARE or not PolygonMorph.is_drawable(piece.points):
			continue
		piece.color = _mix_paint(piece.color, base_paint, (1.0 - amount) * 0.4)
		if piece.area() <= part_area * BACKDROP_SHARE:
			front.append(piece)
		elif not used.has(d):
			back.append(piece)
	_add_to_layer(anchor, ForgedLook.BACK_LAYER, back)
	_add_to_layer(anchor, ForgedLook.FRONT_LAYER, _cap(front, MAX_LEFTOVERS))

static func _add_to_layer(anchor: Node, layer_name: StringName, pieces: Array[Piece]) -> void:
	var layer := anchor.get_node_or_null(NodePath(layer_name))
	if layer == null:
		layer = Node2D.new()
		layer.name = layer_name
		anchor.add_child(layer)
		if layer_name == ForgedLook.BACK_LAYER:
			anchor.move_child(layer, 0)
	for piece in pieces:
		var polygon_node := Polygon2D.new()
		polygon_node.polygon = piece.points
		polygon_node.color = piece.color
		layer.add_child(polygon_node)

static func _root_collision(root: Node) -> CollisionPolygon2D:
	for child in root.get_children():
		if child is CollisionPolygon2D:
			return child
	return null

## The node the base's art is gathered around: the one holding the most art
## directly (a wheel's root, a horse's torso). Scrap layers from an earlier
## forging are left out, and a forged base keeps the anchor it already had.
static func _find_anchor(root: Node, part: PartData) -> Node:
	if part.forge != null:
		var kept := root.get_node_or_null(part.forge.anchor_path)
		if kept != null:
			return kept
	var best: Node = root
	var best_area := -1.0
	for node in _nodes_under(root):
		if not (node is Node2D) or ForgedLook.is_scrap_layer(node):
			continue
		var area := 0.0
		for child in node.get_children():
			if child is Polygon2D:
				area += absf(signed_area((child as Polygon2D).polygon))
		if area > best_area:
			best_area = area
			best = node
	return best

## Writes the blended instance into `look`: every base polygon under the anchor
## becomes an override, scrap-layer polygons become the fused pieces, and mount
## markers keep their bent positions.
static func _bake(root: Node, anchor: Node, look: ForgedLook) -> void:
	var front: Array[Piece] = []
	var back: Array[Piece] = []
	for polygon_node in _polygons_under(anchor):
		var parent := polygon_node.get_parent()
		if parent.name == ForgedLook.FRONT_LAYER:
			front.append(Piece.new(polygon_node.polygon, polygon_node.color))
		elif parent.name == ForgedLook.BACK_LAYER:
			back.append(Piece.new(polygon_node.polygon, polygon_node.color))
		else:
			look.override_paths.append(String(root.get_path_to(polygon_node)))
			look.override_polygons.append(polygon_node.polygon)
			look.override_colors.append(polygon_node.color)
	for piece in _cap(front, MAX_FRONT_SCRAP):
		look.front_polygons.append(piece.points)
		look.front_colors.append(piece.color)
	for piece in _cap(back, MAX_BACK_SCRAP):
		look.back_polygons.append(piece.points)
		look.back_colors.append(piece.color)
	for node in _nodes_under(anchor):
		if node is Marker2D:
			look.marker_paths.append(String(root.get_path_to(node)))
			look.marker_positions.append((node as Marker2D).position)

# --- Reading art -----------------------------------------------------------------

## Every drawn polygon under `root`, in `space`'s coordinates (a node under
## `root`, or `root` itself), in drawing order.
static func harvest(root: Node, space: Node) -> Array[Piece]:
	var to_space := relative_transform(space, root).affine_inverse()
	var pieces: Array[Piece] = []
	for polygon_node in _polygons_under(root):
		if polygon_node.color.a < 0.05 or not _is_drawn(polygon_node, root):
			continue
		var xform := to_space * relative_transform(polygon_node, root)
		var source := polygon_node.polygon
		var subsets: Array = polygon_node.polygons
		if subsets.is_empty():
			subsets = [range(source.size())]
		for subset in subsets:
			var points := PackedVector2Array()
			for index in subset:
				if index < source.size():
					points.append(xform * (source[index] + polygon_node.offset))
			if points.size() >= 3:
				pieces.append(Piece.new(points, polygon_node.color))
	return pieces

## `node`'s transform into `ancestor`'s space.
static func relative_transform(node: Node, ancestor: Node) -> Transform2D:
	var xform := Transform2D.IDENTITY
	var current := node
	while current != null and current != ancestor:
		if current is Node2D:
			xform = (current as Node2D).transform * xform
		current = current.get_parent()
	return xform

static func _is_drawn(node: Node, root: Node) -> bool:
	var current := node
	while current != null:
		if current is CanvasItem and not (current as CanvasItem).visible:
			return false
		if current == root:
			break
		current = current.get_parent()
	return true

static func _nodes_under(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_nodes_under(child))
	return out

static func _polygons_under(root: Node) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	for node in _nodes_under(root):
		if node is Polygon2D:
			out.append(node)
	return out

## The colours of the biggest pieces, biggest first.
static func _palette(pieces: Array) -> Array[Color]:
	var solid := pieces.filter(func(piece: Piece) -> bool: return piece.color.a >= 0.5)
	solid.sort_custom(func(a: Piece, b: Piece) -> bool: return a.area() > b.area())
	var colors: Array[Color] = []
	for piece: Piece in solid.slice(0, 3):
		colors.append(piece.color)
	if colors.is_empty():
		colors.append(Color(0.3, 0.3, 0.32))
	return colors

static func _mix_paint(paint: Color, other: Color, amount: float) -> Color:
	var mixed := paint.lerp(other, amount)
	mixed.a = paint.a
	return mixed

# --- Geometry --------------------------------------------------------------------

static func signed_area(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size():
		total += points[i].cross(points[(i + 1) % points.size()])
	return total * 0.5

static func hull(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var outline := Geometry2D.convex_hull(points)
	if outline.size() > 1 and outline[0] == outline[outline.size() - 1]:
		outline.remove_at(outline.size() - 1)
	return outline

static func bounds_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds

static func _points_of(pieces: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for piece: Piece in pieces:
		points.append_array(piece.points)
	return points

## Extra points along every edge longer than `step`, so the outline can bend.
static func _densify(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size():
		var from := points[i]
		var to := points[(i + 1) % points.size()]
		var cuts := clampi(int(from.distance_to(to) / maxf(step, 0.001)), 1, 16)
		for k in cuts:
			out.append(from.lerp(to, float(k) / cuts))
	return out

## Keeps the `limit` biggest pieces, in their original drawing order.
static func _cap(pieces: Array[Piece], limit: int) -> Array[Piece]:
	if pieces.size() <= limit:
		return pieces
	var order := range(pieces.size())
	order.sort_custom(func(a: int, b: int) -> bool: return pieces[a].area() > pieces[b].area())
	var keep := order.slice(0, limit)
	keep.sort()
	var out: Array[Piece] = []
	for index in keep:
		out.append(pieces[index])
	return out
