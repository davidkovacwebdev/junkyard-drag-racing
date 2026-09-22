@tool
class_name RoadNetwork
extends Node2D
## City roads for the world map: flat asphalt ribbons with lighter shoulders,
## dashed centre lines and solid edge lines. Purely cosmetic — no collision,
## the player just drives over the streets.
##
## There are two ways to define the network, and both go through one renderer:
##
## **Generated** (`mode = GENERATED`) lays out an irregular town from
## `city_seed`: unevenly spaced avenues, side streets that stop short and
## wander, angled boulevards, ring roads, and roundabouts dropped on real
## junctions. The same seed always produces the same city.
##
## **Authored** is the one to reach for when shaping the map by hand: add
## `Path2D` children, select one, then drag its curve points around in the 2D
## view. This is a `@tool` script, so the roads redraw live while you drag — no
## rebuild step, no re-running the game. `COMBINED` draws both.
##
## Every road — generated or authored — ends up as a plain polyline, so they all
## share the same code. Shoulders are drawn for the whole network first, then
## the asphalt on top, which is what makes junctions merge into a single surface
## instead of showing seams. Lane markings then skip any point that lands on
## another road (within `junction_clearance`), so centre dashes and edge lines
## stop at an intersection instead of running straight across it.
##
## `clear_areas` lists plots the generator bends roads around (the garage, by
## default), so a building never ends up in the middle of a street.

enum Mode {
	GENERATED, ## Procedural town from `city_seed` only.
	AUTHORED,  ## Curves of any `Path2D` children only.
	COMBINED,  ## Both at once.
}

## Where the roads come from. Add `Path2D` children and pick AUTHORED to
## hand-draw the whole city.
@export var mode: Mode = Mode.GENERATED

@export_group("Road")
@export var road_width: float = 120.0
@export var shoulder_width: float = 18.0
## Sharp turns (from clear-area dodges, tight authored curves, etc.) get
## rounded into a short arc of this radius instead of staying a hard kink,
## which is what keeps the edge lines from zigzagging on corners.
@export var corner_fillet_radius: float = 90.0
## Only turns sharper than this get filleted — gentle wavy-line bends are
## left untouched.
@export var corner_fillet_angle_deg: float = 50.0

@export_group("Markings")
@export var dash_length: float = 64.0
@export var dash_gap: float = 56.0
@export var line_width: float = 5.0
@export var edge_width: float = 4.0
## How far the solid edge line sits inside the asphalt edge.
@export var edge_inset: float = 12.0
## Lane markings stay this far clear of any other road they run into.
@export var junction_clearance: float = 10.0

@export_group("City")
@export var city_seed: int = 90210
## Area the town is laid out in. Its right edge stays left of the drag strip
## (which starts at world x 1800); the main street alone is extended to meet it.
@export var city_bounds: Rect2 = Rect2(-4600.0, -2400.0, 6200.0, 4800.0)
## Gap between parallel avenues / side streets, re-rolled in this range for each
## one so the blocks never come out even.
@export var avenue_spacing: Vector2 = Vector2(560.0, 920.0)
@export var street_spacing: Vector2 = Vector2(540.0, 880.0)
## Fraction of the town's height a staggered side street spans.
@export var street_span: Vector2 = Vector2(0.3, 0.85)
## How far a street may wander off its nominal line.
@export var avenue_wave: float = 150.0
@export var street_wave: float = 110.0
## Chance an avenue stops short instead of crossing the whole town.
@export_range(0.0, 1.0) var avenue_cut_chance: float = 0.35
## Chance a side street is a short one hanging off a single avenue.
@export_range(0.0, 1.0) var street_cut_chance: float = 0.55
## Extra flourishes: angled boulevards cutting across the grid, and looping
## roads around a district.
@export var diagonal_roads: int = 3
@export var ring_roads: int = 2
@export var ring_radius: Vector2 = Vector2(460.0, 900.0)
## Roundabouts, dropped on genuine avenue/street junctions.
@export var roundabout_count: int = 2
@export var roundabout_radius: float = 150.0
## Plots roads must keep out of — a building footprint, say. A road that would
## clip one bends around it, which is how the garage ends up beside the street
## instead of on it. Update these if you move a building.
@export var clear_areas: Array[Rect2] = [
	Rect2(100.0, -370.0, 320.0, 220.0),  ## The house/garage.
	Rect2(415.0, -360.0, 200.0, 200.0),  ## The shed beside it.
]

@export_group("Colors")
## Asphalt: #4a6e64.
@export var asphalt_color: Color = Color("4a6e64")
## Lighter curb tone, so a road edge blends into the sand.
@export var shoulder_color: Color = Color("78938b")
@export var line_color: Color = Color(0.95, 0.93, 0.68, 0.5)
@export var edge_color: Color = Color(0.9, 0.92, 0.87, 0.4)
@export var island_color: Color = Color(0.52, 0.6, 0.4, 1.0)
@export var island_rim_color: Color = Color(0.88, 0.9, 0.84, 0.8)

## Every road in the network, as polylines in this node's local space. Full
## fidelity — the placement queries read these, so their results must not drift.
var _roads: Array[PackedVector2Array] = []
## Decimated copies of `_roads`, for drawing only. Built alongside `_roads`,
## either from `_cached_generated_draw` or from an `AuthoredRoad`.
var _draw_roads: Array[PackedVector2Array] = []
## Per-road points that need a disc drawn under them, so a bend renders round
## instead of notched.
var _corner_points: Array[PackedVector2Array] = []
## Marking polylines — solid edge lines and centre dashes — already offset,
## densified and clipped at every junction, so `_draw()` only replays them.
var _edge_runs: Array[PackedVector2Array] = []
var _dash_runs: Array[PackedVector2Array] = []
## Junction-clipping broad phase. All the drawing roads' segments flattened into
## `_segment_*`, and a grid mapping a cell to the segments whose own bounding
## box, grown by the marking clearance, covers that cell. A cell's list is
## therefore a superset of the segments that could block a point inside it, so
## `_point_blocked` only ever runs the exact test on those few segments instead
## of scanning whole roads — which matters because a hand-drawn road can be
## thousands of pixels long and touch most of the map.
var _blocking_cells: Dictionary = {}
var _segment_road: PackedInt32Array = []
var _segment_from: PackedVector2Array = []
var _segment_to: PackedVector2Array = []
var _blocking_cell_size: float = 1.0
## Broad phase for `is_on_road`, the one query that runs every physics frame
## while driving. Same shape as `_blocking_cells`, but over the full-fidelity
## `_roads` (the placement queries must see the true polyline) and keyed off the
## caller's own threshold instead of the marking clearance. Without it every
## frame distance-tested all ~12k segments of the city and cost ~5.5 ms on its
## own, which is what made driving around the map stutter.
var _query_cells: Dictionary = {}
var _query_segment_from: PackedVector2Array = []
var _query_segment_to: PackedVector2Array = []
## Derived geometry per authored Path2D child, keyed by instance id. Deriving a
## road from a curve — sampling, clearing the no-build areas, filleting corners,
## decimating — is the most expensive thing a rebuild does, and it depends on
## nothing but that one curve. Caching it means adding or editing one road
## doesn't redo the work for every other road in the scene.
var _authored_cache: Dictionary = {}
## Centres of the generated roundabouts, so their islands can be drawn.
var _roundabouts: Array[Vector2] = []
## Editor-only: snapshot of the inputs, polled so edits get noticed.
var _signature: String = ""

## How far a drawing polyline may deviate from the true one, in pixels. A baked
## curve arrives at one point per 5 px (several thousand on a hand-drawn road)
## and every step of the redraw path scales with that count, so the drawing copy
## is decimated to this tolerance first. Half a pixel is invisible on a 120 px
## wide antialiased ribbon, but still keeps the fillet arcs from being flattened
## away.
const SIMPLIFY_TOLERANCE := 0.5

## Cell size of the `is_on_road` broad phase. Each segment is registered only in
## the cells its own bounding box covers, and a query walks just the cells
## overlapping the square of `threshold` around the point — so the lookup radius
## follows the caller's `extra` instead of being fixed, and the grid stays a
## valid superset at any threshold. Smaller cells mean fewer segments per lookup
## and more cells to check; 128 keeps the common (no-extra) query down to a 2x2
## walk while a wide footprint's reach only widens it to a handful of cells.
const QUERY_CELL_SIZE := 128.0

## What one authored curve contributes to the network.
class AuthoredRoad:
	## Snapshot of the curve when this was derived, so it's only redone on edit.
	var signature := ""
	## Full fidelity, for the placement queries.
	var road := PackedVector2Array()
	## Decimated, for drawing.
	var draw := PackedVector2Array()

# --- Perf: caching -----------------------------------------------------------------
## Fully-generated (and filleted) city roads, kept between rebuilds. Editing an
## authored `Path2D` no longer re-rolls the RNG or re-spreads the grid.
var _cached_generated: Array[PackedVector2Array] = []
## Decimated copies of `_cached_generated`, built alongside it.
var _cached_generated_draw: Array[PackedVector2Array] = []
var _cached_roundabouts: Array[Vector2] = []
## Signature of only the generation inputs. A change here forces a regenerate;
## any other signature change (dragging a path, etc.) only rebuilds the live
## road array out of the cache.
var _generation_signature: String = ""
## Editor polling accumulator — we don't want to hash curves 60× a second.
var _poll_accum: float = 0.0

const POLL_INTERVAL := 0.05

func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		# Dragging a Path2D's curve in the 2D view doesn't notify us, so poll a
		# cheap snapshot of the inputs and redraw when it changes. That's what
		# makes authored roads follow the curve live.
		_signature = _compute_signature()
		set_process(true)
	else:
		set_process(false)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	# Throttle: rebuilding + redrawing is not free, and nobody needs the preview
	# to catch a stale curve within 16 ms. 20 Hz feels live and costs 3× less.
	_poll_accum += delta
	if _poll_accum < POLL_INTERVAL:
		return
	_poll_accum = 0.0
	var signature := _compute_signature()
	if signature != _signature:
		_signature = signature
		_rebuild()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var paths := 0
	for child in get_children():
		if child is Path2D:
			paths += 1
	if mode == Mode.GENERATED and paths > 0:
		warnings.append("This node has %d Path2D child(ren), but mode is GENERATED so they are ignored. Switch mode to AUTHORED or COMBINED to draw them." % paths)
	elif mode != Mode.GENERATED and paths == 0:
		warnings.append("mode is %s but there are no Path2D children. Add one and drag its curve points in the 2D view to author roads." % Mode.find_key(mode))
	return warnings

## Round off any turn sharper than `corner_fillet_angle_deg` by replacing the
## vertex with a short arc, so downstream offsetting (edge lines) and the road
## ribbon never have to handle a near-right-angle kink. Gentle bends from
## `_wavy_line` are left alone.
func _round_sharp_corners(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	if points.size() < 3 or radius <= 0.0:
		return points
	var threshold := deg_to_rad(corner_fillet_angle_deg)
	var out := PackedVector2Array()
	out.append(points[0])
	for i in range(1, points.size() - 1):
		var prev := points[i - 1]
		var curr := points[i]
		var next := points[i + 1]
		var in_dir := curr - prev
		var out_dir := next - curr
		if in_dir.length_squared() < 0.0001 or out_dir.length_squared() < 0.0001:
			out.append(curr)
			continue
		in_dir = in_dir.normalized()
		out_dir = out_dir.normalized()
		if absf(in_dir.angle_to(out_dir)) < threshold:
			out.append(curr)
			continue
		# Don't let the fillet eat more than half of either adjacent segment.
		var r := minf(radius, minf(prev.distance_to(curr), curr.distance_to(next)) * 0.5)
		var p1 := curr - in_dir * r
		var p2 := curr + out_dir * r
		var arc_steps := 6
		for step in arc_steps + 1:
			var t := float(step) / float(arc_steps)
			out.append(p1.lerp(curr, t).lerp(curr.lerp(p2, t), t))
	out.append(points[points.size() - 1])
	return out

func _rebuild() -> void:
	_roads.clear()
	_draw_roads.clear()
	_roundabouts.clear()

	if mode == Mode.GENERATED or mode == Mode.COMBINED:
		var gen_sig := _compute_generation_signature()
		if gen_sig != _generation_signature or _cached_generated.is_empty():
			_generation_signature = gen_sig
			_generate_city()
		# Just re-use the cache — no regeneration, no re-fillet, no re-decimate.
		_roads.append_array(_cached_generated)
		_draw_roads.append_array(_cached_generated_draw)
		_roundabouts.append_array(_cached_roundabouts)

	if mode == Mode.AUTHORED or mode == Mode.COMBINED:
		_append_authored_roads()

	# Everything below is derived from `_roads` and is what a redraw actually
	# needs, so it's all built here — once — rather than inside `_draw()`. The
	# editor emits far more redraws than it does actual edits (selections,
	# property changes, moving the node), and rebuilding that geometry on each
	# of them is what made working with long roads in the editor crawl.
	_rebuild_blocking_grid()
	_rebuild_query_grid()
	_build_markings()
	queue_redraw()

## Sample the Path2D children, reusing whatever is still cached for any curve
## that hasn't been touched since the last rebuild.
func _append_authored_roads() -> void:
	var live := {}
	# Settings that shape a derived road but aren't part of its curve, folded
	# into the cache key so changing either one re-derives every road.
	var settings := str(corner_fillet_radius, corner_fillet_angle_deg, clear_areas)
	for child in get_children():
		if not (child is Path2D):
			continue
		var path := child as Path2D
		var key := path.get_instance_id()
		live[key] = true
		var signature := "%s|%s" % [settings, _path_signature(path)]
		var cached: AuthoredRoad = _authored_cache.get(key)
		if cached == null or cached.signature != signature:
			cached = _derive_authored_road(path, signature)
			_authored_cache[key] = cached
		# A curve with too few points contributes nothing; leaving it out keeps
		# road indices aligned with what actually got drawn.
		if cached.road.size() < 2:
			continue
		_roads.append(cached.road)
		_draw_roads.append(cached.draw)
	# Drop curves that have been deleted or reparented away.
	for key in _authored_cache.keys():
		if not live.has(key):
			_authored_cache.erase(key)

## Turn one authored curve into the geometry it contributes.
func _derive_authored_road(path: Path2D, signature: String) -> AuthoredRoad:
	var cached := AuthoredRoad.new()
	cached.signature = signature
	var points := _sample_curve(path)
	if points.size() >= 2:
		var road := _avoid_clear_areas(points)
		cached.road = _round_sharp_corners(road, corner_fillet_radius)
		cached.draw = _simplify(cached.road, SIMPLIFY_TOLERANCE)
	return cached

## Douglas-Peucker: drop points that stay within `tolerance` of the line between
## the points that survive. Iterative rather than recursive — a pathological
## curve can put thousands of frames on the stack, which GDScript does not like.
func _simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	var n := points.size()
	if n < 3 or tolerance <= 0.0:
		return points
	var keep := PackedByteArray()
	keep.resize(n)
	keep[0] = 1
	keep[n - 1] = 1
	var tolerance_squared := tolerance * tolerance
	var spans: Array[Vector2i] = [Vector2i(0, n - 1)]
	while not spans.is_empty():
		var span: Vector2i = spans.pop_back()
		var first := span.x
		var last := span.y
		if last - first < 2:
			continue
		var a := points[first]
		var ab := points[last] - a
		var length_squared := ab.length_squared()
		var worst := -1.0
		var worst_index := -1
		for i in range(first + 1, last):
			var deviation := 0.0
			if length_squared <= 0.0:
				deviation = points[i].distance_squared_to(a)
			else:
				var t := clampf((points[i] - a).dot(ab) / length_squared, 0.0, 1.0)
				deviation = points[i].distance_squared_to(a + ab * t)
			if deviation > worst:
				worst = deviation
				worst_index = i
		if worst > tolerance_squared:
			keep[worst_index] = 1
			spans.append(Vector2i(first, worst_index))
			spans.append(Vector2i(worst_index, last))
	var out := PackedVector2Array()
	for i in n:
		if keep[i] == 1:
			out.append(points[i])
	return out

## Build the junction-clipping broad phase. Every drawing road's segments are
## flattened, then each one is registered in the grid cells its own bounding box
## covers once grown by the marking clearance. Bucketing that generously makes a
## cell's list a superset of the segments that could block a point inside it, so
## `_point_blocked` only runs the exact test on those few segments.
func _rebuild_blocking_grid() -> void:
	_blocking_cells.clear()
	_segment_road.clear()
	_segment_from.clear()
	_segment_to.clear()
	_blocking_cell_size = maxf(road_width * 0.5 + shoulder_width + junction_clearance, 1.0)
	if _draw_roads.size() < 2:
		return
	# Collect into plain arrays first: a packed array stored in a Dictionary is
	# copied every time it's appended to, which this is about to do a lot of.
	var buckets := {}
	for i in _draw_roads.size():
		var points := _draw_roads[i]
		for s in range(points.size() - 1):
			var segment := _segment_from.size()
			_segment_road.append(i)
			_segment_from.append(points[s])
			_segment_to.append(points[s + 1])
			var rect := Rect2(points[s], Vector2.ZERO).expand(points[s + 1])
			rect = rect.grow(_blocking_cell_size)
			var first := Vector2i((rect.position / _blocking_cell_size).floor())
			var last := Vector2i((rect.end / _blocking_cell_size).floor())
			for cx in range(first.x, last.x + 1):
				for cy in range(first.y, last.y + 1):
					var cell := Vector2i(cx, cy)
					if buckets.has(cell):
						buckets[cell].append(segment)
					else:
						buckets[cell] = [segment]
	for cell in buckets:
		_blocking_cells[cell] = PackedInt32Array(buckets[cell])

## Build the `is_on_road` broad phase. Same bucketing trick as the junction
## grid: each full-fidelity segment lands in every cell its bounding box covers
## once grown by `QUERY_CELL_SIZE`, which makes a cell's list a superset of the
## segments that could possibly be within reach of a point inside it. The query
## then runs the exact distance test on those few segments instead of all of
## them — the difference between ~5.5 ms and ~0.05 ms per frame while driving.
func _rebuild_query_grid() -> void:
	_query_cells.clear()
	_query_segment_from.clear()
	_query_segment_to.clear()
	if _roads.is_empty():
		return
	# Collect into plain arrays first, then pack: a packed array stored in a
	# Dictionary is copied on every append, and this appends a lot.
	var buckets := {}
	for i in _roads.size():
		var points := _roads[i]
		for s in range(points.size() - 1):
			var segment := _query_segment_from.size()
			_query_segment_from.append(points[s])
			_query_segment_to.append(points[s + 1])
			var rect := Rect2(points[s], Vector2.ZERO).expand(points[s + 1])
			var first := Vector2i((rect.position / QUERY_CELL_SIZE).floor())
			var last := Vector2i((rect.end / QUERY_CELL_SIZE).floor())
			for cx in range(first.x, last.x + 1):
				for cy in range(first.y, last.y + 1):
					var cell := Vector2i(cx, cy)
					if buckets.has(cell):
						buckets[cell].append(segment)
					else:
						buckets[cell] = [segment]
	for cell in buckets:
		_query_cells[cell] = PackedInt32Array(buckets[cell])

# --- Queries for other systems -------------------------------------------------

## Build now instead of waiting for `_ready()`. Idempotent, and safe to call
## from a sibling that needs roads already laid out (the roadside prop spawner
## does this, rather than depending on the order siblings happen to be read in).
func ensure_built() -> void:
	if _roads.is_empty():
		_rebuild()

## Every road as a polyline in this node's local space. Callers should not
## modify the result — it's the network's own working data.
func get_road_polylines() -> Array[PackedVector2Array]:
	return _roads

## Distance from a road's centreline out to the far edge of its shoulder. Add a
## gutter to this to sit a prop just off the tarmac.
func road_edge_offset() -> float:
	return road_width * 0.5 + shoulder_width

## True if `point` lands on a road, using the same clearance the lane markings
## respect. `extra` widens the test, e.g. to keep a wide prop's footprint clear.
func is_on_road(point: Vector2, extra: float = 0.0) -> bool:
	var threshold := road_edge_offset() + extra
	# Self-heal if a caller got here before the first rebuild. Cheap, and it
	# keeps a miss from silently answering "no road anywhere".
	if _query_cells.is_empty() and not _roads.is_empty():
		_rebuild_query_grid()
	# Any segment within `threshold` of the point has its bounding box inside
	# the square of that radius, so walking the cells overlapping that square
	# is guaranteed to offer up every segment that could pass the exact test.
	var limit := threshold * threshold
	var first := Vector2i(((point - Vector2(threshold, threshold)) / QUERY_CELL_SIZE).floor())
	var last := Vector2i(((point + Vector2(threshold, threshold)) / QUERY_CELL_SIZE).floor())
	for cx in range(first.x, last.x + 1):
		for cy in range(first.y, last.y + 1):
			var candidates: PackedInt32Array = _query_cells.get(
					Vector2i(cx, cy), PackedInt32Array())
			for segment in candidates:
				if _distance_squared_to_segment(point, _query_segment_from[segment],
						_query_segment_to[segment]) < limit:
					return true
	return false

## Unit direction of the road nearest `point`, or `fallback` if nothing is
## nearby. Lets a prop sit parallel to whatever street it was dropped beside.
func nearest_road_direction(point: Vector2, fallback: Vector2 = Vector2.RIGHT) -> Vector2:
	var best := INF
	var direction := fallback
	for road in _roads:
		for i in range(road.size() - 1):
			var a := road[i]
			var b := road[i + 1]
			var distance := _distance_squared_to_segment(point, a, b)
			if distance < best:
				best = distance
				if not a.is_equal_approx(b):
					direction = (b - a).normalized()
	return direction

## Centres of the generated roundabouts, so callers can keep clear of islands.
func get_roundabouts() -> Array[Vector2]:
	return _roundabouts

# --- Authoring -----------------------------------------------------------------

## Sample a Path2D's curve into a polyline in this node's space, so a hand-drawn
## curve renders through exactly the same path as a generated street.
func _sample_curve(path: Path2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var curve := path.curve
	if curve == null:
		return points
	for point in curve.get_baked_points():
		points.append(path.transform * point)
	return points

# --- City generation -----------------------------------------------------------

## Lay out the procedural town: avenues, staggered side streets, diagonals,
## ring roads, then roundabouts on the junctions between them. Fills the
## `_cached_generated` / `_cached_roundabouts` arrays.
func _generate_city() -> void:
	_cached_generated.clear()
	_cached_roundabouts.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed
	var bounds := _normalized_bounds()

	var avenues: Array[PackedVector2Array] = []
	var streets: Array[PackedVector2Array] = []
	for y in _spread(0.0, bounds.position.y, bounds.end.y, avenue_spacing, rng):
		var avenue := _make_avenue(rng, bounds, y)
		avenues.append(avenue)
		_cached_generated.append(avenue)
	for x in _spread(0.0, bounds.position.x, bounds.end.x, street_spacing, rng):
		var street := _make_street(rng, bounds, x)
		streets.append(street)
		_cached_generated.append(street)
	for i in diagonal_roads:
		_cached_generated.append(_make_diagonal(rng, bounds))
	for i in ring_roads:
		_cached_generated.append(_make_ring(rng, bounds))
	_add_roundabouts(rng, avenues, streets)

	# Fillet once and cache it — fillet params are part of the generation
	# signature, so a change there triggers a regenerate.
	for i in _cached_generated.size():
		_cached_generated[i] = _round_sharp_corners(_cached_generated[i], corner_fillet_radius)

	# Decimate once here too, so a rebuild only re-simplifies authored curves
	# that actually changed.
	_cached_generated_draw.clear()
	for road in _cached_generated:
		_cached_generated_draw.append(_simplify(road, SIMPLIFY_TOLERANCE))

## Street positions stepping outward from `anchor`, re-rolling the gap every
## time so blocks come out uneven. The anchor is always included, which is what
## keeps a main street through 0,0 for the player to spawn on.
func _spread(anchor: float, lo: float, hi: float, spacing: Vector2, rng: RandomNumberGenerator) -> Array[float]:
	var levels: Array[float] = [anchor]
	var value := anchor
	while true:
		value -= rng.randf_range(spacing.x, spacing.y)
		if value < lo:
			break
		levels.append(value)
	value = anchor
	while true:
		value += rng.randf_range(spacing.x, spacing.y)
		if value > hi:
			break
		levels.append(value)
	levels.sort()
	return levels

## An east/west avenue. The main street (y = 0) runs dead straight from the west
## edge to the drag strip; the rest wander, and some stop short of full width.
func _make_avenue(rng: RandomNumberGenerator, bounds: Rect2, y: float) -> PackedVector2Array:
	var main := absf(y) < 1.0
	var left := bounds.position.x
	var right := 1780.0 if main else bounds.end.x
	if not main and rng.randf() < avenue_cut_chance:
		if rng.randf() < 0.5:
			left += bounds.size.x * rng.randf_range(0.12, 0.38)
		else:
			right -= bounds.size.x * rng.randf_range(0.12, 0.38)
	var wave := 0.0 if main else avenue_wave
	return _wavy_line(rng, Vector2(left, y), Vector2(right, y), wave)

## A north/south side street. The one at x = 0 is the main crossroads and stays
## straight; the rest are staggered, so they start and end at different avenues.
func _make_street(rng: RandomNumberGenerator, bounds: Rect2, x: float) -> PackedVector2Array:
	var main := absf(x) < 1.0
	var top := bounds.position.y
	var bottom := bounds.end.y
	if not main and rng.randf() < street_cut_chance:
		var span := bounds.size.y * rng.randf_range(street_span.x, street_span.y)
		var start := rng.randf_range(top, bottom - span)
		top = start
		bottom = start + span
	var wave := 0.0 if main else street_wave
	return _wavy_line(rng, Vector2(x, top), Vector2(x, bottom), wave)

## A gently curving line from `a` to `b`. Two sine harmonics set the shape and
## the `sin(t * PI)` envelope pins both ends, so a street starts and finishes
## exactly where it was told to and only bows in between.
func _wavy_line(rng: RandomNumberGenerator, a: Vector2, b: Vector2, amount: float) -> PackedVector2Array:
	if a.is_equal_approx(b):
		return PackedVector2Array([a, b])
	var segments := rng.randi_range(12, 20)
	var normal := (b - a).normalized().orthogonal()
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var wave := sin(t * PI) * (0.7 * sin(t * 3.1 + phase_a) + 0.6 * sin(t * 5.3 + phase_b))
		points.append(a.lerp(b, t) + normal * wave * amount)
	return _avoid_clear_areas(points)

## An angled boulevard cutting across the grid, entering and leaving by the
## town's edges so it reads as a through route.
func _make_diagonal(rng: RandomNumberGenerator, bounds: Rect2) -> PackedVector2Array:
	var a := _edge_point(rng, bounds)
	var b := _edge_point(rng, bounds)
	var wanted := maxf(bounds.size.x, bounds.size.y) * 0.45
	for _attempt in 8:
		if a.distance_to(b) >= wanted:
			break
		b = _edge_point(rng, bounds)
	return _wavy_line(rng, a, b, avenue_wave * 0.8)

func _edge_point(rng: RandomNumberGenerator, bounds: Rect2) -> Vector2:
	match rng.randi_range(0, 3):
		0:
			return Vector2(rng.randf_range(bounds.position.x, bounds.end.x), bounds.position.y)
		1:
			return Vector2(bounds.end.x, rng.randf_range(bounds.position.y, bounds.end.y))
		2:
			return Vector2(rng.randf_range(bounds.position.x, bounds.end.x), bounds.end.y)
		_:
			return Vector2(bounds.position.x, rng.randf_range(bounds.position.y, bounds.end.y))

## A closed loop around a district: a circle with a few sine ripples so it isn't
## a perfect ring. The last point repeats the first, which closes the ribbon.
func _make_ring(rng: RandomNumberGenerator, bounds: Rect2) -> PackedVector2Array:
	var margin := ring_radius.y * 0.6
	var center := Vector2(
		rng.randf_range(bounds.position.x + margin, bounds.end.x - margin),
		rng.randf_range(bounds.position.y + margin, bounds.end.y - margin))
	var radius := rng.randf_range(ring_radius.x, ring_radius.y)
	var ripple := rng.randf_range(0.08, 0.2)
	var phase := rng.randf_range(0.0, TAU)
	var steps := 28
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := TAU * float(i) / float(steps)
		var r := radius * (1.0 + ripple * sin(angle * 3.0 + phase) + ripple * 0.4 * sin(angle * 5.0))
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return _avoid_clear_areas(points)

## Drop roundabout rings on junctions between avenues and side streets, keeping
## them spread out and clear of the player's spawn crossroads.
func _add_roundabouts(rng: RandomNumberGenerator, avenues: Array[PackedVector2Array], streets: Array[PackedVector2Array]) -> void:
	if roundabout_count <= 0:
		return
	var junctions: Array[Vector2] = []
	for avenue in avenues:
		for street in streets:
			var hit: Variant = _polyline_crossing(avenue, street)
			if hit != null:
				junctions.append(hit as Vector2)
	if junctions.is_empty():
		return
	var chosen: Array[Vector2] = []
	var min_gap := roundabout_radius * 6.0
	var spawn_clear := roundabout_radius * 2.5
	for _attempt in junctions.size():
		var pick: Vector2 = junctions[rng.randi_range(0, junctions.size() - 1)]
		if pick.distance_to(Vector2.ZERO) < spawn_clear:
			continue
		var far_enough := true
		for other in chosen:
			if pick.distance_to(other) < min_gap:
				far_enough = false
				break
		if far_enough:
			chosen.append(pick)
		if chosen.size() >= roundabout_count:
			break
	for center in chosen:
		_cached_roundabouts.append(center)
		_cached_generated.append(_make_roundabout_ring(center))

func _make_roundabout_ring(center: Vector2) -> PackedVector2Array:
	var steps := 32
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * roundabout_radius)
	return points

## Where two polylines cross, or null if they don't.
func _polyline_crossing(a: PackedVector2Array, b: PackedVector2Array) -> Variant:
	for i in range(a.size() - 1):
		for j in range(b.size() - 1):
			var hit: Variant = _segment_hit(a[i], a[i + 1], b[j], b[j + 1])
			if hit != null:
				return hit
	return null

## Where two segments cross, or null. Parallel segments never count.
func _segment_hit(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Variant:
	var d1 := p2 - p1
	var d2 := p4 - p3
	var denominator := d1.cross(d2)
	if absf(denominator) < 0.0001:
		return null
	var delta := p3 - p1
	var t := delta.cross(d2) / denominator
	var u := delta.cross(d1) / denominator
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return null
	return p1 + d1 * t

## Push points out of any keep-clear plot, along whichever axis the road mostly
## runs. A road that would cross a building footprint bends around it instead,
## which is what keeps buildings off the tarmac.
func _avoid_clear_areas(points: PackedVector2Array) -> PackedVector2Array:
	if clear_areas.is_empty() or points.size() < 2:
		return points
	var margin := road_width * 0.5 + shoulder_width + 6.0
	var out := PackedVector2Array()
	for i in points.size():
		var point := points[i]
		var direction := _local_direction(points, i)
		for area in clear_areas:
			var grown := area.grow(margin)
			if not grown.has_point(point):
				continue
			if absf(direction.x) >= absf(direction.y):
				point.y = grown.position.y if absf(point.y - grown.position.y) < absf(point.y - grown.end.y) else grown.end.y
			else:
				point.x = grown.position.x if absf(point.x - grown.position.x) < absf(point.x - grown.end.x) else grown.end.x
		out.append(point)
	return out

func _local_direction(points: PackedVector2Array, index: int) -> Vector2:
	if index == 0:
		return points[1] - points[0]
	if index == points.size() - 1:
		return points[index] - points[index - 1]
	return points[index + 1] - points[index - 1]

func _normalized_bounds() -> Rect2:
	var rect := city_bounds
	if rect.size.x < 0.0:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	if rect.size.y < 0.0:
		rect.position.y += rect.size.y
		rect.size.y = -rect.size.y
	return rect

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	if _roads.is_empty() or _corner_points.size() != _draw_roads.size():
		return
	# 1. Shoulders under the whole network...
	for i in _draw_roads.size():
		_draw_ribbon(_draw_roads[i], _corner_points[i],
				road_width + shoulder_width * 2.0, shoulder_color)
	# 2. ...then the asphalt, so junctions read as one surface.
	for i in _draw_roads.size():
		_draw_ribbon(_draw_roads[i], _corner_points[i], road_width, asphalt_color)
	# 3. Roundabout islands sit on top of the asphalt.
	for center in _roundabouts:
		_draw_island(center)
	# 4. Markings last, stopping short of any road they meet. Every one of these
	# polylines was already offset, densified and junction-clipped by
	# `_build_markings()`, so a redraw only has to replay them.
	for run in _edge_runs:
		draw_polyline(run, edge_color, edge_width, true)
	for run in _dash_runs:
		draw_polyline(run, line_color, line_width, true)

## A road surface: a thick line with a disc at every *corner* (`corners`, worked
## out once in `_corners_of`), so bends come out round instead of notched.
## Collinear samples don't get a disc — the polyline itself already covers them.
func _draw_ribbon(points: PackedVector2Array, corners: PackedVector2Array,
		width: float, color: Color) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, color, width, true)
	var radius := width * 0.5
	draw_circle(points[0], radius, color)
	draw_circle(points[points.size() - 1], radius, color)
	for corner in corners:
		draw_circle(corner, radius, color)

func _draw_island(center: Vector2) -> void:
	var radius := maxf(roundabout_radius - road_width * 0.5 + 2.0, 8.0)
	draw_circle(center, radius, island_color)
	draw_arc(center, radius - edge_width * 0.5, 0.0, TAU, 48, island_rim_color, edge_width, true)
	draw_circle(center, radius * 0.16, island_rim_color)

# --- Geometry ------------------------------------------------------------------

## Everything a marking needs, worked out once per rebuild: where the discs go
## under the ribbon, and the polylines to draw. This is the expensive half of a
## redraw — offsetting both kerbs, densifying them, and testing every mark
## against every other road — so it must not live in `_draw()`, which the editor
## calls again on every poll that sees a curve change.
func _build_markings() -> void:
	_edge_runs.clear()
	_dash_runs.clear()
	_corner_points.clear()
	for i in _draw_roads.size():
		var points := _draw_roads[i]
		_corner_points.append(_corners_of(points))
		_collect_edge_runs(points, i)
		_collect_dash_runs(points, i)

## The points along a road that need a disc under them. ~3° — anything
## straighter than this is effectively collinear at road scale.
func _corners_of(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	const MIN_TURN := 0.05
	for i in range(1, points.size() - 1):
		var a := points[i] - points[i - 1]
		var b := points[i + 1] - points[i]
		if a.length_squared() < 0.0001 or b.length_squared() < 0.0001:
			continue
		if absf(a.angle_to(b)) > MIN_TURN:
			out.append(points[i])
	return out

## Solid edge lines down both sides, broken wherever another road crosses.
func _collect_edge_runs(points: PackedVector2Array, index: int) -> void:
	var inset := road_width * 0.5 - edge_inset
	if inset <= 0.0:
		return
	_collect_line_runs(_offset_polyline(points, -inset), index, _edge_runs)
	_collect_line_runs(_offset_polyline(points, inset), index, _edge_runs)

## Cut a polyline into the runs that don't land on another road.
func _collect_line_runs(points: PackedVector2Array, index: int,
		out_runs: Array[PackedVector2Array]) -> void:
	var dense := _densify(points, maxf(road_width * 0.3, 24.0))
	var run := PackedVector2Array()
	for point in dense:
		if _point_blocked(point, index):
			_append_run(out_runs, run)
			run = PackedVector2Array()
		else:
			run.append(point)
	_append_run(out_runs, run)

## Dashed centre line, cut into one run per dash so the gaps stay gaps.
##
## The dash edges are placed at their exact arc-length positions rather than at
## whichever densified sample happened to land nearest. Sampling quantises every
## dash edge by up to one sample spacing, and the drawing polyline is decimated,
## so its samples sit much further apart than the full-fidelity ones did — that
## alone was trimming roughly 10% off every dash. Deriving the edges from
## distance along the road keeps `dash_length`/`dash_gap` exact no matter how
## heavily the polyline was decimated for drawing.
func _collect_dash_runs(points: PackedVector2Array, index: int) -> void:
	var dense := _densify(points, 14.0)
	if dense.size() < 2:
		return
	var period := maxf(dash_length + dash_gap, 1.0)
	var total := 0.0
	for i in range(1, dense.size()):
		total += dense[i].distance_to(dense[i - 1])
	var edges := _dash_edges(total, period)

	var run := PackedVector2Array()
	var on_dash := fmod(dash_gap, period) < dash_length
	if on_dash:
		# The road opens part-way through a dash.
		run.append(dense[0])
	var edge_index := 0
	var travelled := 0.0
	for i in range(1, dense.size()):
		var a := dense[i - 1]
		var b := dense[i]
		var segment_length := a.distance_to(b)
		var segment_end := travelled + segment_length
		# Place any dash edge that falls inside this step, exactly where it
		# belongs. The point is tested for blocking like any other, so a dash
		# still breaks at a junction.
		while edge_index < edges.size() and edges[edge_index] <= segment_end + 0.0001:
			var t := 0.0 if segment_length <= 0.0 else (edges[edge_index] - travelled) / segment_length
			var at := a.lerp(b, clampf(t, 0.0, 1.0))
			if on_dash:
				if not _point_blocked(at, index):
					run.append(at)
				_append_run(_dash_runs, run)
				run = PackedVector2Array()
			elif not _point_blocked(at, index):
				run.append(at)
			on_dash = not on_dash
			edge_index += 1
		if on_dash:
			if _point_blocked(b, index):
				_append_run(_dash_runs, run)
				run = PackedVector2Array()
			else:
				run.append(b)
		travelled = segment_end
	_append_run(_dash_runs, run)

## Arc-length positions where the centre line flips between dash and gap. The
## marking turns on at `k*period - dash_gap` and off `dash_length` later.
func _dash_edges(total: float, period: float) -> PackedFloat32Array:
	var edges := PackedFloat32Array()
	var k := 0
	while true:
		var off_edge := k * period + dash_length - dash_gap
		if off_edge > total + period:
			break
		var on_edge := k * period - dash_gap
		if on_edge >= 0.0 and on_edge <= total:
			edges.append(on_edge)
		if off_edge >= 0.0 and off_edge <= total:
			edges.append(off_edge)
		k += 1
	edges.sort()
	return edges

## One point is not a line — only keep runs worth drawing.
func _append_run(out_runs: Array[PackedVector2Array], run: PackedVector2Array) -> void:
	if run.size() >= 2:
		out_runs.append(run)

## Is this marking point sitting on some other road? The grid narrows it to the
## handful of segments that could actually reach this point; without that, every
## call had to distance-test every segment of every other road, which cost about
## a second per redraw once the roads got long.
func _point_blocked(point: Vector2, index: int) -> bool:
	# A one-road network has nothing to collide with.
	var candidates: PackedInt32Array = _blocking_cells.get(
			Vector2i((point / _blocking_cell_size).floor()), PackedInt32Array())
	if candidates.is_empty():
		return false
	var threshold := road_width * 0.5 + shoulder_width + junction_clearance
	var limit := threshold * threshold
	for segment in candidates:
		if _segment_road[segment] == index:
			continue
		if _distance_squared_to_segment(point, _segment_from[segment],
				_segment_to[segment]) < limit:
			return true
	return false

func _distance_squared_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0:
		return point.distance_squared_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(a + ab * t)

func _offset_polyline(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	if n < 2:
		return out
	var miter_limit := 2.0 # max miter length, as a multiple of `distance`
	for i in n:
		var offset_dir: Vector2
		if i == 0:
			offset_dir = (points[1] - points[0]).normalized().orthogonal()
		elif i == n - 1:
			offset_dir = (points[i] - points[i - 1]).normalized().orthogonal()
		else:
			var t_in := (points[i] - points[i - 1]).normalized()
			var t_out := (points[i + 1] - points[i]).normalized()
			var n_in := t_in.orthogonal()
			var n_out := t_out.orthogonal()
			var bisector := n_in + n_out
			if bisector.length_squared() < 0.0001:
				# Near-180 reversal — no clean bisector, just use one side.
				offset_dir = n_in
			else:
				bisector = bisector.normalized()
				var cos_half := bisector.dot(n_in)
				if cos_half < 1.0 / miter_limit:
					# Too sharp to miter without folding — bevel: sit at the
					# mean of the two side normals so the line simply turns.
					offset_dir = bisector * cos_half
				else:
					offset_dir = bisector / cos_half
		out.append(points[i] + offset_dir * distance)
	return _trim_offset_loops(out)

## A parallel offset is only valid while the road curves more gently than the
## offset distance. Around a corner tighter than that, the offset points on the
## inside cross back over themselves and the line renders as a broken loop.
## Walk the offset and, whenever the newest segment crosses an earlier one, cut
## the loop out at the crossing — leaving the clean cusp an inner edge line
## should have. Loops are local to the tight corner, so only a short window of
## recent points has to be tested.
func _trim_offset_loops(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 4:
		return points
	const LOOP_WINDOW := 64
	var out := PackedVector2Array()
	out.append(points[0])
	for i in range(1, points.size()):
		# Drop duplicate points — they only confuse the segment-crossing test.
		if points[i].distance_squared_to(out[out.size() - 1]) > 0.01:
			out.append(points[i])
		var guard := 0
		while out.size() >= 4 and guard < LOOP_WINDOW:
			guard += 1
			var last := out.size() - 1
			var first := maxi(0, last - LOOP_WINDOW)
			var clipped := false
			for j in range(first, last - 2):
				var hit: Variant = Geometry2D.segment_intersects_segment(
						out[j], out[j + 1], out[last - 1], out[last])
				if hit == null:
					continue
				var trimmed := out.slice(0, j + 1)
				trimmed.append(hit as Vector2)
				out = trimmed
				clipped = true
				break
			if not clipped:
				break
	return out

## Subdivide long segments, so marks are laid out at a sane resolution along a
## road that's made of only a handful of far-apart points.
func _densify(points: PackedVector2Array, max_length: float) -> PackedVector2Array:
	if points.size() < 2 or max_length <= 0.0:
		return points
	var out := PackedVector2Array()
	out.append(points[0])
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var steps := maxi(int(ceil(a.distance_to(b) / max_length)), 1)
		for step in range(1, steps + 1):
			out.append(a.lerp(b, float(step) / float(steps)))
	return out

# --- Editor polling ------------------------------------------------------------

## Signature of only the inputs the *generator* consumes. Unchanged across a
## rebuild means the cached generated roads can be reused verbatim.
func _compute_generation_signature() -> String:
	var parts := PackedStringArray()
	for value in [city_seed, city_bounds, avenue_spacing, street_spacing,
			street_span, avenue_wave, street_wave, avenue_cut_chance,
			street_cut_chance, diagonal_roads, ring_roads, ring_radius,
			roundabout_count, roundabout_radius, clear_areas, road_width,
			shoulder_width, corner_fillet_radius, corner_fillet_angle_deg]:
		parts.append(str(value))
	return "|".join(parts)

## Cheap snapshot of every input `_rebuild()` depends on. Compared each editor
## poll to notice curve edits (and inspector changes) and redraw.
func _compute_signature() -> String:
	var parts := PackedStringArray()
	# Everything that feeds the baked geometry or the draw calls, not just what
	# the generator reads: markings and ribbons are now computed in `_rebuild()`
	# instead of live in `_draw()`, so an export missing from here would leave
	# the preview stale until the next unrelated edit.
	for value in [mode, city_seed, city_bounds, avenue_spacing, street_spacing,
			street_span, avenue_wave, street_wave, avenue_cut_chance,
			street_cut_chance, diagonal_roads, ring_roads, ring_radius,
			roundabout_count, roundabout_radius, clear_areas, road_width,
			shoulder_width, corner_fillet_radius, corner_fillet_angle_deg,
			dash_length, dash_gap, line_width, edge_width, edge_inset,
			junction_clearance, asphalt_color, shoulder_color, line_color,
			edge_color, island_color, island_rim_color]:
		parts.append(str(value))
	for child in get_children():
		if child is Path2D:
			parts.append(_path_signature(child as Path2D))
	return "|".join(parts)

## Snapshot of a single authored curve: its name, placement, and the position and
## Bezier handles of every control point.
func _path_signature(path: Path2D) -> String:
	var parts := PackedStringArray()
	parts.append(str(path.name, path.transform))
	var curve := path.curve
	if curve == null:
		parts.append("no-curve")
		return "|".join(parts)
	parts.append(str(curve.point_count, curve.bake_interval))
	for i in curve.point_count:
		# The in/out control points (the Bezier handles) are what shape the
		# baked polyline, so dragging a handle has to count as an edit —
		# otherwise the preview keeps the old, angular shape and only catches up
		# when the scene is reloaded.
		parts.append(str(curve.get_point_position(i),
				curve.get_point_in(i), curve.get_point_out(i)))
	return "|".join(parts)
