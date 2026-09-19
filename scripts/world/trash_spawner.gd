class_name TrashSpawner
extends Node2D
## Scatters lootable `TrashProp`s along the city's roads — bins and dumpsters
## sitting on the shoulder, never on the tarmac.
##
## It reads the road polylines out of the `RoadNetwork` and walks each one at
## irregular intervals, dropping a prop on a randomly chosen side. Spots that
## land on another road (junctions), inside a building footprint, on a
## roundabout island, over the drag strip, or too close to a prop already placed
## are skipped, so the result reads as deliberately placed rather than sprinkled.
##
## Deterministic for a given `prop_seed`, so the same props come back in the same
## spots every time the map reloads — which is what lets `WorldState` remember
## which ones have been looted and bring them back empty.
##
## Props are added to this node's **parent**, not to this node. In main.tscn that
## parent is the Y-sorted `Sortables` node, so each prop sorts against the car by
## its own Y (its ground contact point) instead of the whole set being sorted at
## whatever Y this spawner happens to sit at.

## Palette props pick their body colour from, so a street of bins doesn't come
## out looking stamped from one mould.
@export var body_palette: Array[Color] = [
	Color(0.34, 0.42, 0.4, 1),   # weathered green
	Color(0.38, 0.4, 0.43, 1),   # grey steel
	Color(0.46, 0.36, 0.3, 1),   # rust brown
	Color(0.3, 0.36, 0.44, 1),   # dumpster blue
	Color(0.42, 0.34, 0.36, 1),  # dull maroon
]

@export_group("Layout")
## Seed for the layout. Change it for a different scatter of the same city.
@export var prop_seed: int = 4242
## Distance along a road between candidate spots, re-rolled each step so props
## never fall into an even rhythm.
@export var spacing_min: float = 300.0
@export var spacing_max: float = 700.0
## Gap between the road's shoulder edge and the prop's own footprint.
@export var gutter: float = 12.0
## Closest two props may sit to each other, so they don't bunch up.
@export var min_spacing: float = 240.0
## Hard ceiling on how many props the map gets.
@export var max_props: int = 80
@export_range(0.0, 1.0) var container_chance: float = 0.28
## Chance a candidate spot is skipped outright, to thin the scatter unevenly.
@export_range(0.0, 1.0) var skip_chance: float = 0.25

@export_group("Sources")
## Where the roads come from. Left at the default, `_resolve_roads()` falls back
## to searching the scene for any `RoadNetwork` if this path doesn't resolve.
@export var roads_path: NodePath = ^"../Roads"
@export var container_scene: PackedScene = preload("res://scenes/world/trash_container.tscn")
@export var bin_scene: PackedScene = preload("res://scenes/world/trash_bin.tscn")

@export_group("Keep-out")
## Plots props must stay out of, on top of the road network's own `clear_areas`.
## Defaults to the drag strip, whose asphalt starts at world x 1800.
@export var keep_out_areas: Array[Rect2] = [Rect2(1720.0, -560.0, 3300.0, 1120.0)]

func _ready() -> void:
	# Deferred so it runs once the whole scene has come up: the road node is
	# guaranteed to exist by then, and we're not adding children to a parent that
	# is still mid-setup, which Godot refuses outright.
	scatter.call_deferred()

## Place every prop. Safe to call again — it clears what it made first, so it can
## be re-run from the editor or after changing the seed.
func scatter() -> void:
	for child in get_parent().get_children():
		if child.is_in_group(&"trash"):
			# Frees immediately rather than queueing, so a re-scatter in the same
			# frame doesn't briefly double up the props.
			child.get_parent().remove_child(child)
			child.free()
	var roads := _resolve_roads()
	if roads == null:
		push_warning("TrashSpawner: no RoadNetwork found, so no trash props were placed.")
		return
	roads.ensure_built()

	var rng := RandomNumberGenerator.new()
	rng.seed = prop_seed
	var placed: Array[Vector2] = []
	var index := 0
	for road in roads.get_road_polylines():
		var length := _polyline_length(road)
		if length < 160.0:
			continue
		var travelled := rng.randf_range(spacing_min, spacing_max)
		while travelled < length and index < max_props:
			var sample: Array = _sample_along(road, travelled)
			travelled += rng.randf_range(spacing_min, spacing_max)
			if rng.randf() < skip_chance:
				continue
			var use_container := rng.randf() < container_chance
			var found: Variant = _find_spot(roads, sample, use_container, rng, placed)
			if typeof(found) != TYPE_VECTOR2:
				continue
			var spot: Vector2 = found
			if not _place_prop(spot, use_container, rng, index):
				continue
			placed.append(spot)
			index += 1

## The road network to hang props off, by the exported path or, failing that, the
## first one anywhere in the scene.
func _resolve_roads() -> RoadNetwork:
	var node := get_node_or_null(roads_path)
	if node is RoadNetwork:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is RoadNetwork:
			return current
		for child in current.get_children():
			stack.append(child)
	return null

## A spot beside the road for a prop of the given kind, or null if both sides are
## taken. Tries each side so a blocked shoulder still gets a fair chance.
func _find_spot(roads: RoadNetwork, sample: Array, want_container: bool,
		rng: RandomNumberGenerator, placed: Array[Vector2]) -> Variant:
	var point: Vector2 = sample[0]
	var direction: Vector2 = sample[1]
	if direction.length_squared() <= 0.0:
		return null
	var kind := TrashProp.Kind.CONTAINER if want_container else TrashProp.Kind.BIN
	var footprint := TrashProp.footprint_for(kind)
	var normal := direction.normalized().orthogonal()
	# Props never rotate, so how far one straddles the road depends on how the
	# road is angled: the footprint's half-extents projected onto the normal. A
	# road running along Y needs the prop's full 150px width cleared; one running
	# along X only needs its 22px depth.
	var reach := absf(normal.x) * footprint.x * 0.5 + absf(normal.y) * footprint.y * 0.5
	var radius := footprint.length() * 0.5
	var offset := roads.road_edge_offset() + gutter + reach
	var sides: Array[float] = [1.0, -1.0]
	if rng.randf() < 0.5:
		sides.reverse()
	for side: float in sides:
		var spot: Vector2 = point + normal * (side * offset)
		if _is_clear(roads, spot, reach, radius, placed):
			return spot
	return null

## Everything a spot has to satisfy to be usable. `reach` is the half-width of the
## prop measured across the road; `radius` is the circumscribed radius used for
## the blob-shaped keep-outs.
func _is_clear(roads: RoadNetwork, spot: Vector2, reach: float, radius: float,
		placed: Array[Vector2]) -> bool:
	# Rejecting anywhere within `reach` of a centreline keeps the whole footprint
	# off the asphalt, and incidentally rules out junctions, where another road's
	# centreline is close by.
	if roads.is_on_road(spot, reach):
		return false
	for area in roads.clear_areas:
		if area.grow(radius).has_point(spot):
			return false
	for center in roads.get_roundabouts():
		if spot.distance_to(center) < roads.roundabout_radius + radius:
			return false
	for area in keep_out_areas:
		if area.grow(radius).has_point(spot):
			return false
	for other in placed:
		if spot.distance_to(other) < min_spacing:
			return false
	return true

## Instantiate one prop and drop it in beside the road. Returns false if the
## scene wasn't set, so the caller doesn't count it as placed.
func _place_prop(spot: Vector2, use_container: bool, rng: RandomNumberGenerator,
		index: int) -> bool:
	var scene: PackedScene = container_scene if use_container else bin_scene
	if scene == null:
		return false
	var prop := scene.instantiate() as TrashProp
	if prop == null:
		return false
	# Set this before the prop enters the tree: its `_ready()` reads the id to
	# find out whether it was already looted, and captures `display_name` as the
	# prompt it later blanks out when emptied.
	prop.loot_id = "%d:%d" % [prop_seed, index]
	prop.variant_seed = rng.randi()
	prop.display_name = "Trash Container" if use_container else "Trash Bin"
	if not body_palette.is_empty():
		prop.body_color = body_palette[rng.randi_range(0, body_palette.size() - 1)]
	prop.position = spot
	# Props stay upright: this is a side-on world, so a rotated bin would just
	# look broken rather than turned to face the street.
	prop.rotation = 0.0
	prop.add_to_group(&"trash")
	get_parent().add_child(prop)
	return true

# --- Polyline helpers ----------------------------------------------------------

func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

## Point and unit direction `distance` along a polyline, as `[Vector2, Vector2]`.
func _sample_along(points: PackedVector2Array, distance: float) -> Array:
	var travelled := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segment := a.distance_to(b)
		if segment <= 0.0:
			continue
		if travelled + segment >= distance:
			var t := (distance - travelled) / segment
			return [a.lerp(b, t), (b - a) / segment]
		travelled += segment
	var last := points[points.size() - 1]
	var previous := points[points.size() - 2]
	return [last, (last - previous).normalized()]
