class_name TrashSpawner
extends Node2D
## Places the city's lootable `TrashProp`s: a bin at each house's kerb, plus
## dumpsters scattered along the roads. Every prop sits on the shoulder, never
## on the tarmac.
##
## Bins are not random — there is exactly one per house, dropped at the house's
## own road frontage. `HouseSpawner` records a `Plot` for each house (where it
## landed and which stretch of kerb it fronts on); this reads those back and
## puts a bin in front of each one. Where the house is set too close to the road
## for the bin to fit squarely in the gap, the bin steps along the road to the
## house's side instead — still at the kerb, still beside its house.
##
## Containers stay random: it reads the road polylines out of the `RoadNetwork`
## and walks each one at irregular intervals, dropping a dumpster on a randomly
## chosen side. Spots that land on another road (junctions), inside a building
## footprint, on a roundabout island, over the drag strip, or too close to a
## prop already placed are skipped, so the result reads as deliberately placed
## rather than sprinkled.
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
## Hard ceiling on how many props (house bins plus random containers) the map
## gets.
@export var max_props: int = 80
## Chance a candidate container spot is skipped outright, to thin the scatter
## unevenly.
@export_range(0.0, 1.0) var skip_chance: float = 0.25

@export_group("Sources")
## Where the roads come from. Left at the default, `_resolve_roads()` falls back
## to searching the scene for any `RoadNetwork` if this path doesn't resolve.
@export var roads_path: NodePath = ^"../Roads"
## Where the houses come from, so each one can get a bin at its kerb. Left at
## the default, `_resolve_houses()` falls back to searching the scene for any
## `HouseSpawner`, the same idea as `roads_path`.
@export var houses_path: NodePath = ^"../Houses"
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

	# One bin per house, at the house's own kerb. The plots carry the house
	# geometry, so a bin lands in front of its house rather than wherever a
	# road walk happened to stop.
	var houses := _resolve_houses()
	var plots: Array = []
	if houses == null:
		push_warning("TrashSpawner: no HouseSpawner found, so no bins were placed.")
	else:
		houses.ensure_scattered()
		plots = houses.get_plots()
		for plot: HouseSpawner.Plot in plots:
			if _place_house_bin(roads, plot, rng, placed, index):
				index += 1

	# Dumpsters stay random: a walk along each road, dropping one wherever the
	# shoulder has room and it is clear of the houses.
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
			var found: Variant = _find_spot(roads, sample, rng, placed, plots)
			if typeof(found) != TYPE_VECTOR2:
				continue
			var spot: Vector2 = found
			if not _place_prop(spot, true, rng, index):
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

## The house spawner to take bin plots from, by the exported path or, failing
## that, the first one anywhere in the scene — same resolution `_resolve_roads`
## uses, and for the same reason.
func _resolve_houses() -> HouseSpawner:
	var node := get_node_or_null(houses_path)
	if node is HouseSpawner:
		return node
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_parent()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is HouseSpawner:
			return current
		for child in current.get_children():
			stack.append(child)
	return null

## A spot beside the road for a container, or null if both sides are taken.
## Tries each side so a blocked shoulder still gets a fair chance.
func _find_spot(roads: RoadNetwork, sample: Array,
		rng: RandomNumberGenerator, placed: Array[Vector2],
		house_plots: Array) -> Variant:
	var point: Vector2 = sample[0]
	var direction: Vector2 = sample[1]
	if direction.length_squared() <= 0.0:
		return null
	var footprint := TrashProp.footprint_for(TrashProp.Kind.CONTAINER)
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
		if _is_clear(roads, spot, reach, radius, placed, house_plots):
			return spot
	return null

## The bin spot for one house: at the kerb, on the house's side of the road, in
## front of the house. A house set far enough back leaves room for the bin to
## sit squarely in the gap; one whose front edge is closer to the road than the
## bin is deep gets the bin shifted along the kerb to its side instead, so the
## bin never overlaps the wall. Returns null only if the shoulder is blocked.
func _bin_spot_for(roads: RoadNetwork, plot: HouseSpawner.Plot,
		rng: RandomNumberGenerator, placed: Array[Vector2]) -> Variant:
	var polylines := roads.get_road_polylines()
	if plot.direction.length_squared() <= 0.0 \
			or plot.road_index < 0 or plot.road_index >= polylines.size():
		return null
	var polyline: PackedVector2Array = polylines[plot.road_index]
	var footprint := TrashProp.footprint_for(TrashProp.Kind.BIN)
	var half := footprint * 0.5
	var normal := plot.direction.orthogonal()
	# A bin isn't round, so project its footprint onto the road axes and clear
	# the shape a car would actually hit.
	var reach := absf(normal.x) * half.x + absf(normal.y) * half.y
	var along := absf(plot.direction.x) * half.x + absf(plot.direction.y) * half.y
	var offset := roads.road_edge_offset() + gutter + reach
	# The house's road-facing edge, out from the centreline on the house's side.
	var house_center := (plot.spot - plot.road_point).dot(normal) * plot.side
	var house_front := house_center - plot.cross_reach
	# Does the bin, sitting at the kerb, poke past that edge? If so it would
	# overlap the wall, so step it along the kerb clear of the house instead.
	var shift := 0.0
	if offset + reach > house_front:
		shift = plot.along_reach + along + gutter
	var sides: Array[float] = [1.0, -1.0]
	if rng.randf() < 0.5:
		sides.reverse()
	for side: float in sides:
		# Step along the road's own polyline rather than along the tangent
		# through `road_point`: on a bend that tangent points off the road, and
		# the bin would ride it onto the tarmac. Re-sampling keeps the bin at
		# the kerb however the road curves.
		var sample: Array = _sample_along(polyline, plot.road_distance + side * shift)
		var local_dir: Vector2 = sample[1]
		if local_dir.length_squared() <= 0.0:
			continue
		var local_normal: Vector2 = local_dir.orthogonal()
		if local_normal.dot(normal) < 0.0:
			local_normal = -local_normal
		var spot: Vector2 = sample[0] + local_normal * (plot.side * offset)
		# No house keep-out here: a bin belongs at its own kerb, and its own
		# house is the one plot it must not be excluded by.
		if _is_clear(roads, spot, reach, footprint.length() * 0.5, placed):
			return spot
	return null

## Place the bin for one house, if its kerb spot is clear. Returns false when
## nothing was placed, so the caller doesn't count it.
func _place_house_bin(roads: RoadNetwork, plot: HouseSpawner.Plot,
		rng: RandomNumberGenerator, placed: Array[Vector2], index: int) -> bool:
	var found: Variant = _bin_spot_for(roads, plot, rng, placed)
	if typeof(found) != TYPE_VECTOR2:
		return false
	var spot: Vector2 = found
	if not _place_prop(spot, false, rng, index):
		return false
	placed.append(spot)
	return true

## Everything a spot has to satisfy to be usable. `reach` is the half-width of the
## prop measured across the road; `radius` is the circumscribed radius used for
## the blob-shaped keep-outs. `house_plots` may be empty — a bin passes none,
## because it belongs at its own house's kerb; containers pass the plots so they
## keep out of every building footprint.
func _is_clear(roads: RoadNetwork, spot: Vector2, reach: float, radius: float,
		placed: Array[Vector2], house_plots: Array = []) -> bool:
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
	for plot: HouseSpawner.Plot in house_plots:
		if _house_blocks(plot, spot, radius):
			return false
	return true

## True if a circle of `radius` at `spot` touches the house's footprint,
## measured in the house's own road frame (along the road, and out across it).
func _house_blocks(plot: HouseSpawner.Plot, spot: Vector2, radius: float) -> bool:
	var normal := plot.direction.orthogonal()
	var rel := spot - plot.road_point
	var along := rel.dot(plot.direction)
	var cross := rel.dot(normal) * plot.side
	var house_cross := (plot.spot - plot.road_point).dot(normal) * plot.side
	var gap := Vector2(
		clampf(along, -plot.along_reach, plot.along_reach) - along,
		clampf(cross, house_cross - plot.cross_reach, house_cross + plot.cross_reach) - cross)
	return gap.length_squared() <= radius * radius

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
