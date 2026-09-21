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
## Asphalt band width (the drivable part), and how far the lighter shoulder
## pokes out past it on each side.
@export var road_width: float = 120.0
@export var shoulder_width: float = 18.0

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

## Every road in the network, as polylines in this node's local space.
var _roads: Array[PackedVector2Array] = []
## Per-road bounding box grown by the marking clearance, for cheap rejection.
var _road_bounds: Array[Rect2] = []
## Centres of the generated roundabouts, so their islands can be drawn.
var _roundabouts: Array[Vector2] = []
## Editor-only: snapshot of the inputs, polled so edits get noticed.
var _signature: String = ""

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

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
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

## Rebuild every road from the current inputs. Runs on ready, and again
## whenever the inputs change while the editor is open.
func _rebuild() -> void:
	_roads.clear()
	_roundabouts.clear()
	if mode == Mode.GENERATED or mode == Mode.COMBINED:
		_generate_city()
	if mode == Mode.AUTHORED or mode == Mode.COMBINED:
		for child in get_children():
			if child is Path2D:
				var points := _sample_curve(child as Path2D)
				if points.size() >= 2:
					_roads.append(_avoid_clear_areas(points))
	_rebuild_bounds()
	queue_redraw()

## Cache a grown bounding box per road, so `_point_blocked` can throw out
## distant roads with one rect test.
func _rebuild_bounds() -> void:
	_road_bounds.clear()
	var margin := road_width * 0.5 + shoulder_width + junction_clearance
	for road in _roads:
		var rect := Rect2(road[0], Vector2.ZERO)
		for point in road:
			rect = rect.expand(point)
		_road_bounds.append(rect.grow(margin))

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
	for road in _roads:
		if _polyline_within(point, road, threshold):
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
## ring roads, then roundabouts on the junctions between them.
func _generate_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed
	var bounds := _normalized_bounds()

	var avenues: Array[PackedVector2Array] = []
	var streets: Array[PackedVector2Array] = []
	for y in _spread(0.0, bounds.position.y, bounds.end.y, avenue_spacing, rng):
		var avenue := _make_avenue(rng, bounds, y)
		avenues.append(avenue)
		_roads.append(avenue)
	for x in _spread(0.0, bounds.position.x, bounds.end.x, street_spacing, rng):
		var street := _make_street(rng, bounds, x)
		streets.append(street)
		_roads.append(street)
	for i in diagonal_roads:
		_roads.append(_make_diagonal(rng, bounds))
	for i in ring_roads:
		_roads.append(_make_ring(rng, bounds))
	_add_roundabouts(rng, avenues, streets)

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
		_roundabouts.append(center)
		_roads.append(_make_roundabout_ring(center))

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
	if _roads.is_empty():
		return
	# 1. Shoulders under the whole network...
	for road in _roads:
		_draw_ribbon(road, road_width + shoulder_width * 2.0, shoulder_color)
	# 2. ...then the asphalt, so junctions read as one surface.
	for road in _roads:
		_draw_ribbon(road, road_width, asphalt_color)
	# 3. Roundabout islands sit on top of the asphalt.
	for center in _roundabouts:
		_draw_island(center)
	# 4. Markings last, stopping short of any road they meet.
	for i in _roads.size():
		_draw_edge_lines(_roads[i], i)
		_draw_center_dashes(_roads[i], i)

## A road surface: a thick line with a disc at every vertex, so bends come out
## round instead of notched.
func _draw_ribbon(points: PackedVector2Array, width: float, color: Color) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, color, width, true)
	for point in points:
		draw_circle(point, width * 0.5, color)

## Solid edge lines down both sides, broken wherever another road crosses.
func _draw_edge_lines(points: PackedVector2Array, index: int) -> void:
	var inset := road_width * 0.5 - edge_inset
	if inset <= 0.0:
		return
	_draw_line_runs(_offset_polyline(points, -inset), index, edge_color, edge_width)
	_draw_line_runs(_offset_polyline(points, inset), index, edge_color, edge_width)

## Dashed centre line, built as one run per dash so the gaps stay gaps.
func _draw_center_dashes(points: PackedVector2Array, index: int) -> void:
	var dense := _densify(points, 14.0)
	if dense.size() < 2:
		return
	var period := maxf(dash_length + dash_gap, 1.0)
	var travelled := 0.0
	var run := PackedVector2Array()
	for i in dense.size():
		if i > 0:
			travelled += dense[i].distance_to(dense[i - 1])
		var on_dash := fmod(travelled + dash_gap, period) < dash_length
		if on_dash and not _point_blocked(dense[i], index):
			run.append(dense[i])
		else:
			_flush_line(run, line_color, line_width)
			run = PackedVector2Array()
	_flush_line(run, line_color, line_width)

## Draw a polyline in pieces, skipping any run that lands on another road.
func _draw_line_runs(points: PackedVector2Array, index: int, color: Color, width: float) -> void:
	var dense := _densify(points, maxf(road_width * 0.3, 24.0))
	var run := PackedVector2Array()
	for point in dense:
		if _point_blocked(point, index):
			_flush_line(run, color, width)
			run = PackedVector2Array()
		else:
			run.append(point)
	_flush_line(run, color, width)

func _flush_line(run: PackedVector2Array, color: Color, width: float) -> void:
	if run.size() >= 2:
		draw_polyline(run, color, width, true)

func _draw_island(center: Vector2) -> void:
	var radius := maxf(roundabout_radius - road_width * 0.5 + 2.0, 8.0)
	draw_circle(center, radius, island_color)
	draw_arc(center, radius - edge_width * 0.5, 0.0, TAU, 48, island_rim_color, edge_width, true)
	draw_circle(center, radius * 0.16, island_rim_color)

# --- Geometry ------------------------------------------------------------------

## Is this marking point sitting on some other road? Roads are rejected by
## bounding box first, which is what keeps this cheap on a city-sized network.
func _point_blocked(point: Vector2, index: int) -> bool:
	var threshold := road_width * 0.5 + shoulder_width + junction_clearance
	for i in _roads.size():
		if i == index or not _road_bounds[i].has_point(point):
			continue
		if _polyline_within(point, _roads[i], threshold):
			return true
	return false

func _polyline_within(point: Vector2, points: PackedVector2Array, threshold: float) -> bool:
	var limit := threshold * threshold
	for i in range(points.size() - 1):
		if _distance_squared_to_segment(point, points[i], points[i + 1]) < limit:
			return true
	return false

func _distance_squared_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0:
		return point.distance_squared_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(a + ab * t)

## Shift a polyline sideways by `distance`, using the averaged normal at each
## vertex so the offset line stays parallel through bends.
func _offset_polyline(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2:
		return out
	for i in points.size():
		var direction := _local_direction(points, i)
		var normal := Vector2.ZERO
		if direction.length_squared() > 0.0:
			normal = direction.normalized().orthogonal()
		out.append(points[i] + normal * distance)
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

## Cheap snapshot of every input `_rebuild()` depends on. Compared each editor
## frame to notice curve edits (and inspector changes) and redraw.
func _compute_signature() -> String:
	var parts := PackedStringArray()
	for value in [mode, city_seed, city_bounds, avenue_spacing, street_spacing,
			street_span, avenue_wave, street_wave, avenue_cut_chance,
			street_cut_chance, diagonal_roads, ring_roads, ring_radius,
			roundabout_count, roundabout_radius, clear_areas, road_width,
			shoulder_width, asphalt_color, shoulder_color, line_color, edge_color,
			island_color, island_rim_color]:
		parts.append(str(value))
	for child in get_children():
		if child is Path2D:
			var path := child as Path2D
			parts.append(str(path.name, path.transform))
			var curve := path.curve
			if curve == null:
				parts.append("no-curve")
				continue
			parts.append(str(curve.point_count))
			for i in curve.point_count:
				parts.append(str(curve.get_point_position(i)))
	return "|".join(parts)
