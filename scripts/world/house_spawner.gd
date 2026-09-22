class_name HouseSpawner
extends Node2D
## Scatters ComposedBuilding houses along the city's roads — a sparse row of
## plots on the shoulder, well clear of the tarmac and of each other.
## Mirrors TrashSpawner's own road-walking placement (same "sample along the
## polyline, offer both sides, reject a spot that fails any check" shape),
## just with far wider spacing and bigger footprints: a street of houses
## should read as a handful of landmarks, not a wall of clutter.
##
## Wall/roof/door/window/decoration scenes are preloaded directly rather
## than scanned via BuildingDatabase, which is deliberately editor-only (it
## walks res:// with DirAccess, which doesn't see individual files once a
## project is exported into a .pck). Picking parts at random from these
## fixed lists and handing the result to ComposedBuilding is exactly what
## the Building Creator dock's own Randomize button does, just done here at
## scatter time instead of by hand.
##
## Deterministic for a given `house_seed`, same idea as TrashSpawner's
## `prop_seed` — the same houses come back in the same spots every reload.
##
## Each placed house also records a `Plot` — where it landed, and which
## stretch of kerb it fronts on. `TrashSpawner` reads those back (through
## `get_plots()`) so it can drop exactly one bin at each house's kerb
## instead of scattering bins at random along the roads.

## Where one house ended up, plus the road it fronts on. Enough for a caller
## to work out where that house's kerb-side bin belongs: the house's own
## origin, a point on the road's centreline, the road's direction there,
## which shoulder of that road the house is on, the house's half-extents
## projected onto the road's along/cross axes, and which polyline of the
## network that kerb belongs to plus how far along it the house sits — so a
## caller can step along the road the same way this spawner walked it rather
## than trusting a tangent that points off the road on a bend.
class Plot:
	var spot: Vector2
	var road_point: Vector2
	var direction: Vector2
	var side: float
	var along_reach: float
	var cross_reach: float
	## Index into `RoadNetwork.get_road_polylines()` of the road `road_point`
	## lies on, or -1 if unknown.
	var road_index: int = -1
	## Distance along that polyline from its first point to `road_point`.
	var road_distance: float = 0.0

@export var wall_scenes: Array[PackedScene] = [
	preload("res://scenes/buildings/parts/walls/wall_plank.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_brick.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_corrugated.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_plywood.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_cinderblock.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_tarp.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_rusty_metal.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_cracked_concrete.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_cardboard.tscn"),
	preload("res://scenes/buildings/parts/walls/wall_pallet.tscn"),
]
@export var roof_scenes: Array[PackedScene] = [
	preload("res://scenes/buildings/parts/roofs/roof_flat.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_peaked.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_corrugated_tin.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_tarp_lean.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_patched.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_satellite.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_rusty_peaked.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_ac_unit.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_sandbags.tscn"),
	preload("res://scenes/buildings/parts/roofs/roof_barrels.tscn"),
]
@export var door_scenes: Array[PackedScene] = [
	preload("res://scenes/buildings/parts/doors/door_plain.tscn"),
	preload("res://scenes/buildings/parts/doors/door_boarded.tscn"),
	preload("res://scenes/buildings/parts/doors/door_garage_roll.tscn"),
	preload("res://scenes/buildings/parts/doors/door_riot_shutter.tscn"),
	preload("res://scenes/buildings/parts/doors/door_curtain_beads.tscn"),
	preload("res://scenes/buildings/parts/doors/door_peeling_paint.tscn"),
	preload("res://scenes/buildings/parts/doors/door_broken_hanging.tscn"),
	preload("res://scenes/buildings/parts/doors/door_chained.tscn"),
	preload("res://scenes/buildings/parts/doors/door_cardboard_flap.tscn"),
	preload("res://scenes/buildings/parts/doors/door_steel_peephole.tscn"),
]
@export var window_scenes: Array[PackedScene] = [
	preload("res://scenes/buildings/parts/windows/window_square.tscn"),
	preload("res://scenes/buildings/parts/windows/window_boarded.tscn"),
	preload("res://scenes/buildings/parts/windows/window_broken.tscn"),
	preload("res://scenes/buildings/parts/windows/window_barred.tscn"),
	preload("res://scenes/buildings/parts/windows/window_round_porthole.tscn"),
	preload("res://scenes/buildings/parts/windows/window_taped_plastic.tscn"),
	preload("res://scenes/buildings/parts/windows/window_shutter.tscn"),
	preload("res://scenes/buildings/parts/windows/window_curtained.tscn"),
	preload("res://scenes/buildings/parts/windows/window_chickenwire.tscn"),
	preload("res://scenes/buildings/parts/windows/window_single_grimy.tscn"),
]
@export var decoration_scenes: Array[PackedScene] = [
	preload("res://scenes/buildings/parts/decorations/decoration_antenna.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_pipe.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_oil_barrel.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_tires.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_trash_bags.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_crate_stack.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_hubcaps.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_warning_sign.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_string_lights.tscn"),
	preload("res://scenes/buildings/parts/decorations/decoration_broken_ladder.tscn"),
]

@export_group("Layout")
## Seed for the layout. Change it for a different scatter of the same city.
@export var house_seed: int = 7373
## Distance along a road between candidate spots, re-rolled each step. Much
## wider than TrashSpawner's — houses are landmarks, not litter.
@export var spacing_min: float = 900.0
@export var spacing_max: float = 1700.0
## Gap between the road's shoulder edge and the house's own footprint.
@export var gutter: float = 50.0
## Closest two houses may sit to each other, so the street doesn't bunch up.
@export var min_spacing: float = 700.0
## Hard ceiling on how many houses the map gets.
@export var max_houses: int = 14
@export_range(0.0, 1.0) var window_chance: float = 0.7
@export_range(0.0, 1.0) var decoration_chance: float = 0.55
## Chance a candidate spot is skipped outright, to keep the scatter sparse
## and uneven rather than one-per-interval.
@export_range(0.0, 1.0) var skip_chance: float = 0.4

@export_group("Sources")
## Where the roads come from. Left at the default, `_resolve_roads()` falls
## back to searching the scene for any `RoadNetwork` if this path doesn't
## resolve — see TrashSpawner, which has the same fallback for the same
## reason (the spawner doesn't actually sit next to Roads in the tree).
@export var roads_path: NodePath = ^"../Roads"
@export var house_scene: PackedScene = preload("res://scenes/world/composed_building.tscn")

@export_group("Keep-out")
## Plots houses must stay out of, on top of the road network's own
## `clear_areas`. Defaults to the drag strip (asphalt starts at world x
## 1800, same box TrashSpawner uses) and the junkyard entrance.
@export var keep_out_areas: Array[Rect2] = [
	Rect2(1720.0, -560.0, 3300.0, 1120.0),
	Rect2(-780.0, 180.0, 560.0, 340.0),
]

## Every house placed, in placement order. Read by TrashSpawner to put a bin
## at each house's kerb. Empty until the first `scatter()`.
var _plots: Array[Plot] = []
## Whether `scatter()` has run, so `ensure_scattered()` lays the houses out
## exactly once no matter who asks for them first.
var _scattered: bool = false

func _ready() -> void:
	# Deferred so it runs once the whole scene has come up: the road node is
	# guaranteed to exist by then, and we're not adding children to a
	# parent that is still mid-setup, which Godot refuses outright.
	ensure_scattered.call_deferred()

## Lay the houses out, but only once. TrashSpawner calls this before reading
## the plots — it may be read before this node's own deferred scatter, and
## both paths have to produce exactly one set of houses.
func ensure_scattered() -> void:
	if _scattered:
		return
	scatter()

## The houses placed by `scatter()`, in placement order. See `Plot`.
func get_plots() -> Array[Plot]:
	return _plots

## Place every house. Safe to call again — it clears what it made first, so
## it can be re-run from the editor or after changing the seed.
func scatter() -> void:
	_scattered = true
	_plots.clear()
	for child in get_parent().get_children():
		if child.is_in_group(&"house"):
			child.get_parent().remove_child(child)
			child.free()
	if wall_scenes.is_empty() or house_scene == null:
		return
	var roads := _resolve_roads()
	if roads == null:
		push_warning("HouseSpawner: no RoadNetwork found, so no houses were placed.")
		return
	roads.ensure_built()

	var rng := RandomNumberGenerator.new()
	rng.seed = house_seed
	var placed: Array[Vector2] = []
	var index := 0
	var polylines := roads.get_road_polylines()
	for road_index in polylines.size():
		var road: PackedVector2Array = polylines[road_index]
		var length := _polyline_length(road)
		if length < 300.0:
			continue
		var travelled := rng.randf_range(spacing_min, spacing_max)
		while travelled < length and index < max_houses:
			var along := travelled
			var sample: Array = _sample_along(road, travelled)
			travelled += rng.randf_range(spacing_min, spacing_max)
			if rng.randf() < skip_chance:
				continue
			var data := _random_building(rng)
			var found: Variant = _find_spot(roads, sample, data, rng, placed, road_index, along)
			if found == null:
				continue
			var plot: Plot = found
			_place_house(plot.spot, data, index)
			_plots.append(plot)
			placed.append(plot.spot)
			index += 1
		if index >= max_houses:
			break

## The road network to hang houses off, by the exported path or, failing
## that, the first one anywhere in the scene.
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

## Wall/roof/door always chosen; window and decoration are the "how busy
## does this one look" roll, same as the dock's own randomize_building().
func _random_building(rng: RandomNumberGenerator) -> BuildingData:
	var data := BuildingData.new()
	data.wall_scene = wall_scenes[rng.randi_range(0, wall_scenes.size() - 1)]
	if not roof_scenes.is_empty():
		data.roof_scene = roof_scenes[rng.randi_range(0, roof_scenes.size() - 1)]
	if not door_scenes.is_empty():
		data.door_scene = door_scenes[rng.randi_range(0, door_scenes.size() - 1)]
	if not window_scenes.is_empty() and rng.randf() < window_chance:
		data.window_scene = window_scenes[rng.randi_range(0, window_scenes.size() - 1)]
	if not decoration_scenes.is_empty() and rng.randf() < decoration_chance:
		data.decoration_scene = decoration_scenes[rng.randi_range(0, decoration_scenes.size() - 1)]
	return data

## The plot beside the road for this house's footprint, or null if both sides
## are taken. Tries each side so a blocked shoulder still gets a fair
## chance — same shape as TrashSpawner._find_spot, sized off the building's
## own footprint instead of a fixed prop size. Returns a `Plot` so a caller
## can also work out where the house's kerb-side bin belongs. `road_index`
## and `road_distance` say which road and where along it the kerb is.
func _find_spot(roads: RoadNetwork, sample: Array, data: BuildingData,
		rng: RandomNumberGenerator, placed: Array[Vector2],
		road_index: int, road_distance: float) -> Variant:
	var point: Vector2 = sample[0]
	var direction: Vector2 = sample[1]
	if direction.length_squared() <= 0.0:
		return null
	var footprint := BuildingAssembler.get_footprint_size(data)
	var along_dir := direction.normalized()
	var normal := along_dir.orthogonal()
	var cross_reach := absf(normal.x) * footprint.x * 0.5 + absf(normal.y) * footprint.y * 0.5
	var along_reach := absf(along_dir.x) * footprint.x * 0.5 + absf(along_dir.y) * footprint.y * 0.5
	var radius := footprint.length() * 0.5
	var offset := roads.road_edge_offset() + gutter + cross_reach
	var sides: Array[float] = [1.0, -1.0]
	if rng.randf() < 0.5:
		sides.reverse()
	for side: float in sides:
		var spot: Vector2 = point + normal * (side * offset)
		if _is_clear(roads, spot, cross_reach, radius, placed):
			var plot := Plot.new()
			plot.spot = spot
			plot.road_point = point
			plot.direction = along_dir
			plot.side = side
			plot.along_reach = along_reach
			plot.cross_reach = cross_reach
			plot.road_index = road_index
			plot.road_distance = road_distance
			return plot
	return null

func _is_clear(roads: RoadNetwork, spot: Vector2, reach: float, radius: float,
		placed: Array[Vector2]) -> bool:
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

func _place_house(spot: Vector2, data: BuildingData, _index: int) -> void:
	var house := house_scene.instantiate() as ComposedBuilding
	if house == null:
		return
	house.building_data = data
	house.position = spot
	house.add_to_group(&"house")
	get_parent().add_child(house)

# --- Polyline helpers, identical to TrashSpawner's ------------------------

func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

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
