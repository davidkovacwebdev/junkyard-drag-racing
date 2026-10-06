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
##
## The point-heavy geometry (decimating, filleting, kerb offsets, markings,
## chunking and the lookup grids) runs natively: RoadGeometry and SegmentGrid in
## rust/src/road_geometry.rs.

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
## Junction-clipping broad phase over the drawing roads: each segment is listed
## in every cell its bounding box covers once grown by the marking clearance, so
## a marking point only tests the few segments that could actually block it.
var _blocking_grid: SegmentGrid
## Broad phase for `is_on_road`, the one query that runs every physics frame
## while driving. Over the full-fidelity `_roads` (the placement queries must see
## the true polyline) and walked by the caller's own threshold. Without it every
## frame distance-tested all ~12k segments of the city.
var _query_grid: SegmentGrid
## Derived geometry per authored Path2D child, keyed by instance id. Deriving a
## road from a curve — sampling, clearing the no-build areas, filleting corners,
## decimating — is the most expensive thing a rebuild does, and it depends on
## nothing but that one curve. Caching it means adding or editing one road
## doesn't redo the work for every other road in the scene.
var _authored_cache: Dictionary = {}
## Chunk cell -> DrawChunk.
var _draw_chunks: Dictionary = {}
## One container per `ChunkLayer`, holding that layer's chunk canvases.
var _layer_containers: Array[Node2D] = []
## Per layer: chunk cell -> the Node2D that draws it.
var _chunk_canvases: Array[Dictionary] = []
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

## Side of one drawing chunk, in pixels. The network is drawn as a grid of
## these rather than as one canvas item spanning the whole island, so Godot
## culls every chunk the camera can't see. One big item meant redrawing every
## road on the map each frame.
const DRAW_CHUNK_SIZE := 2048.0

## Draw order across all chunks: every shoulder, then every bit of asphalt, then
## markings, so junctions merge into one surface even across a chunk seam.
enum ChunkLayer { SHOULDERS, ASPHALT, MARKINGS }

## One chunk's share of the drawing geometry.
class DrawChunk:
	var ribbons: Array[PackedVector2Array] = []
	var discs := PackedVector2Array()
	var islands := PackedVector2Array()
	## Every edge line and dash, baked into one draw command.
	var markings := TriangleBatch.new()

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

## Everything `_rebuild()` derives, kept across map reloads. Every exit from
## the garage, a race or a shop reloads main.tscn, and deriving the network
## from scratch cost ~400 ms each time for roads that never change at runtime.
class BakedNetwork:
	var signature := ""
	var roads: Array[PackedVector2Array] = []
	var draw_roads: Array[PackedVector2Array] = []
	var roundabouts: Array[Vector2] = []
	var corner_points: Array[PackedVector2Array] = []
	var edge_runs: Array[PackedVector2Array] = []
	var dash_runs: Array[PackedVector2Array] = []
	var blocking_grid: SegmentGrid
	var query_grid: SegmentGrid
	var draw_chunks: Dictionary = {}

static var _runtime_bake: BakedNetwork = null

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
	return RoadGeometry.round_sharp_corners(points, radius, deg_to_rad(corner_fillet_angle_deg))

func _rebuild() -> void:
	var runtime_signature := ""
	if not Engine.is_editor_hint():
		runtime_signature = _compute_signature()
		if _runtime_bake != null and _runtime_bake.signature == runtime_signature:
			_restore_bake(_runtime_bake)
			_sync_chunk_canvases()
			return
	_derive_network()
	if not Engine.is_editor_hint():
		_runtime_bake = _capture_bake(runtime_signature)
	_sync_chunk_canvases()

func _derive_network() -> void:
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
	_build_draw_chunks()

func _capture_bake(signature: String) -> BakedNetwork:
	var bake := BakedNetwork.new()
	bake.signature = signature
	bake.roads = _roads
	bake.draw_roads = _draw_roads
	bake.roundabouts = _roundabouts
	bake.corner_points = _corner_points
	bake.edge_runs = _edge_runs
	bake.dash_runs = _dash_runs
	bake.blocking_grid = _blocking_grid
	bake.query_grid = _query_grid
	bake.draw_chunks = _draw_chunks
	return bake

## The baked arrays are shared, not copied — nothing mutates them outside a
## rebuild, and a rebuild with a matching signature never runs.
func _restore_bake(bake: BakedNetwork) -> void:
	_roads = bake.roads
	_draw_roads = bake.draw_roads
	_roundabouts = bake.roundabouts
	_corner_points = bake.corner_points
	_edge_runs = bake.edge_runs
	_dash_runs = bake.dash_runs
	_blocking_grid = bake.blocking_grid
	_query_grid = bake.query_grid
	_draw_chunks = bake.draw_chunks

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
		cached.draw = RoadGeometry.simplify(cached.road, SIMPLIFY_TOLERANCE)
	return cached

func _rebuild_blocking_grid() -> void:
	var roads: Array[PackedVector2Array] = _draw_roads if _draw_roads.size() >= 2 else []
	var cell_size := maxf(_marking_block_distance(), 1.0)
	_blocking_grid = SegmentGrid.create(roads, cell_size, cell_size)

## How close a lane marking may get to another road before it breaks.
func _marking_block_distance() -> float:
	return road_width * 0.5 + shoulder_width + junction_clearance

func _rebuild_query_grid() -> void:
	_query_grid = SegmentGrid.create(_roads, QUERY_CELL_SIZE, 0.0)

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

## Decimated copies of the roads, for anything that only needs to draw them.
func get_draw_polylines() -> Array[PackedVector2Array]:
	return _draw_roads

## Distance from a road's centreline out to the far edge of its shoulder. Add a
## gutter to this to sit a prop just off the tarmac.
func road_edge_offset() -> float:
	return road_width * 0.5 + shoulder_width

## True if `point` lands on a road, using the same clearance the lane markings
## respect. `extra` widens the test, e.g. to keep a wide prop's footprint clear.
func is_on_road(point: Vector2, extra: float = 0.0) -> bool:
	# Self-heal if a caller got here before the first rebuild. Cheap, and it
	# keeps a miss from silently answering "no road anywhere".
	if _query_grid == null:
		_rebuild_query_grid()
	return _query_grid.is_near(point, road_edge_offset() + extra)

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
	var curve := path.curve
	if curve == null:
		return PackedVector2Array()
	return path.transform * curve.get_baked_points()

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
		_cached_generated_draw.append(RoadGeometry.simplify(road, SIMPLIFY_TOLERANCE))

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
	return RoadGeometry.avoid_clear_areas(points, clear_areas, road_width * 0.5 + shoulder_width + 6.0)

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

## Draw every chunk's share of the network: the chunk data is rebuilt with
## the markings, then each layer container's chunk canvases are reused where
## their cell survived, freed where it didn't, and redrawn.
func _sync_chunk_canvases() -> void:
	if _layer_containers.is_empty():
		for layer in ChunkLayer.values():
			var container := Node2D.new()
			container.name = "Draw%s" % ChunkLayer.find_key(layer).capitalize()
			add_child(container, false, Node.INTERNAL_MODE_FRONT)
			_layer_containers.append(container)
			_chunk_canvases.append({})
	for layer in ChunkLayer.values():
		var canvases: Dictionary = _chunk_canvases[layer]
		for cell in canvases.keys():
			if not _draw_chunks.has(cell):
				canvases[cell].queue_free()
				canvases.erase(cell)
		for cell in _draw_chunks:
			if not canvases.has(cell):
				var canvas := Node2D.new()
				canvas.draw.connect(_draw_chunk_layer.bind(canvas, cell, layer))
				_layer_containers[layer].add_child(canvas)
				canvases[cell] = canvas
			canvases[cell].queue_redraw()

func _draw_chunk_layer(canvas: Node2D, cell: Vector2i, layer: ChunkLayer) -> void:
	var chunk: DrawChunk = _draw_chunks.get(cell)
	if chunk == null:
		return
	match layer:
		ChunkLayer.SHOULDERS:
			_draw_ribbons(canvas, chunk, road_width + shoulder_width * 2.0, shoulder_color)
		ChunkLayer.ASPHALT:
			_draw_ribbons(canvas, chunk, road_width, asphalt_color)
		ChunkLayer.MARKINGS:
			for center in chunk.islands:
				_draw_island(canvas, center)
			# Markings are thin enough that loose segments show no seam at the
			# bends. An anti-aliased multiline costs a command per segment, which
			# is thousands on screen when zoomed out, so they come pre-baked.
			chunk.markings.commit(canvas)

## A road surface: thick lines with a disc at every corner, end and chunk seam,
## so bends and the joins between chunks come out round instead of notched.
func _draw_ribbons(canvas: Node2D, chunk: DrawChunk, width: float, color: Color) -> void:
	for ribbon in chunk.ribbons:
		canvas.draw_polyline(ribbon, color, width, true)
	var radius := width * 0.5
	for disc in chunk.discs:
		canvas.draw_circle(disc, radius, color)

func _draw_island(canvas: Node2D, center: Vector2) -> void:
	var radius := maxf(roundabout_radius - road_width * 0.5 + 2.0, 8.0)
	canvas.draw_circle(center, radius, island_color)
	canvas.draw_arc(center, radius - edge_width * 0.5, 0.0, TAU, 48, island_rim_color, edge_width, true)
	canvas.draw_circle(center, radius * 0.16, island_rim_color)

## Sort the finished drawing geometry into chunks. Ribbons are cut wherever
## they cross into another chunk; marking runs go in as loose segments.
func _build_draw_chunks() -> void:
	_draw_chunks.clear()
	var markings := {"corner_points": _corner_points, "edge_runs": _edge_runs, "dash_runs": _dash_runs}
	var style := {"chunk_size": DRAW_CHUNK_SIZE, "edge_color": edge_color, "edge_width": edge_width,
			"line_color": line_color, "line_width": line_width}
	var built := RoadGeometry.build_draw_chunks(_draw_roads, markings, _roundabouts, style)
	for cell in built:
		var parts: Dictionary = built[cell]
		var chunk := DrawChunk.new()
		chunk.ribbons.assign(parts["ribbons"])
		chunk.discs = parts["discs"]
		chunk.islands = parts["islands"]
		chunk.markings.add_triangles(parts["points"], parts["colors"], parts["indices"])
		_draw_chunks[cell] = chunk

# --- Geometry ------------------------------------------------------------------

## Everything a marking needs, worked out once per rebuild: where the discs go
## under the ribbon, and the edge lines and centre dashes, already offset,
## densified and broken at every junction. This is the expensive half of a
## redraw, so it must not live in `_draw()`, which the editor calls again on
## every poll that sees a curve change.
func _build_markings() -> void:
	var settings := {"road_width": road_width, "edge_inset": edge_inset, "dash_length": dash_length,
			"dash_gap": dash_gap, "block_distance": _marking_block_distance()}
	var built := RoadGeometry.build_markings(_draw_roads, _blocking_grid, settings)
	_corner_points.assign(built["corner_points"])
	_edge_runs.assign(built["edge_runs"])
	_dash_runs.assign(built["dash_runs"])

func _distance_squared_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0:
		return point.distance_squared_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(a + ab * t)

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
