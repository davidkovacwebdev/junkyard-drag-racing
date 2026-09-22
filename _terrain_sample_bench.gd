extends SceneTree
## Throwaway: verifies the curvature-based sampling in
## `TerrainNetwork._sample_curve()` on coastlines that genuinely curve.
##
## The test curves are Catmull-Rom style: each anchor's handles are
## (next - previous) / 6, so the runs actually bow between anchors. (An earlier
## version angled the handles at the neighbouring anchors, which made every
## segment collinear with its own chord — a 26-gon, on which no sampler has
## anything to decide. `anchor deviation` below is the guard against that: if it
## is near zero, the "curve" is straight and the whole test is meaningless.)
##
## Measured per tolerance: sampled point count, worst deviation from the true
## baked curve (px), island build time, and — the number that matters — full
## `_rebuild()` in authored mode.

const MAIN_MARKERS := [
	{"name": "Plains", "pos": Vector2(300, -200), "biome": 0},
	{"name": "Scrub", "pos": Vector2(2900, 700), "biome": 1},
	{"name": "Desert", "pos": Vector2(-442, 1472), "biome": 2},
	{"name": "Forest", "pos": Vector2(-4786, -1178), "biome": 1},
	{"name": "Swamp", "pos": Vector2(1900, 2000), "biome": 4},
	{"name": "Mountain", "pos": Vector2(5502, -589), "biome": 5},
	{"name": "Snow", "pos": Vector2(1692, -3156), "biome": 4},
]

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	for shape in [_smooth_island(), _wiggly_coast()]:
		_report(shape)

	print("\n=== GENERATED regression (main.tscn config, no Path2D children) ===")
	var generated := _generated_terrain()
	root.add_child(generated)
	var gen_rebuild := _time_ms(30, func() -> void: generated._rebuild())
	var polys := 0
	var points := 0
	for island in generated._islands:
		for band in [island.shore, island.foam, island.beach, island.land, island.inland]:
			polys += band.size()
			points += _points(band)
	print("_rebuild = %.2f ms, bands %d polys / %d pts, biome_at(0,0) = %d (0 = PLAINS)"
			% [gen_rebuild, polys, points, generated.biome_at(Vector2.ZERO)])
	for i in generated._islands.size():
		var island: TerrainNetwork.Island = generated._islands[i]
		print("island %d coast=%d shore=%d foam=%d beach=%d land=%d inland=%d patches=%d"
				% [i, island.coastline.size(), _points(island.shore), _points(island.foam),
					_points(island.beach), _points(island.land), _points(island.inland),
					island.patches.size()])
	print("(must match the pre-change snapshot: 3 islands, 15 bands, 1431 pts)")

	quit()

func _report(path: Path2D) -> void:
	var baked := _sample_at(path, 0.0)
	var anchors := PackedVector2Array()
	for i in path.curve.point_count:
		anchors.append(path.curve.get_point_position(i))
	print("\n=== %s ===" % path.name)
	print("anchors=%d  baked=%d pts  perimeter=%.0f px  curvature check: anchors sit %.1f px off the true curve"
			% [path.curve.point_count, baked.size(), _perimeter(baked), _max_deviation(baked, anchors)])

	print("%-10s %7s %13s %14s %14s" % ["tol(deg)", "pts", "max dev(px)", "_build_island", "rebuild"])
	var reference := _authored_terrain(path, 0.0)
	root.add_child(reference)
	for tolerance in [2.0, 1.0, 0.5, 0.25]:
		var poly := _sample_at(path, tolerance)
		var build := _time_ms(20, func() -> void:
			_terrain()._build_island(poly))
		var land := _authored_terrain(path, tolerance)
		root.add_child(land)
		var rebuild := _time_ms(10, func() -> void: land._rebuild())
		print("%-10s %7d %12.3f %13.2fms %13.2fms"
				% [str(tolerance), poly.size(), _max_deviation(baked, poly), build, rebuild])
		land.queue_free()
	var baked_rebuild := _time_ms(3, func() -> void: reference._rebuild())
	print("%-10s %7d %12.3f %13.2fms %13.2fms" % ["baked(0)", baked.size(), 0.0,
			_time_ms(3, func() -> void: _terrain()._build_island(baked)), baked_rebuild])

	# Classification must survive the cheaper sampling.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var probes: Array[Vector2] = []
	var extent := _extent(baked)
	for _i in 3000:
		probes.append(Vector2(rng.randf_range(-extent, extent), rng.randf_range(-extent, extent)))
	for tolerance in [2.0, 1.0]:
		var candidate := _authored_terrain(path, tolerance)
		root.add_child(candidate)
		var mismatch := 0
		for probe in probes:
			if candidate.is_on_land(probe) != reference.is_on_land(probe):
				mismatch += 1
		print("   is_on_land vs baked, tol %s: %d/3000 differ" % [str(tolerance), mismatch])
		candidate.queue_free()
	reference.queue_free()

## A big smooth island: 26 anchors on a lumpy loop, Catmull-Rom handles.
func _smooth_island() -> Path2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var radii := PackedFloat32Array()
	for _i in 26:
		radii.append(rng.randf_range(3200.0, 5200.0))
	var anchors := PackedVector2Array()
	for i in 26:
		var angle := TAU * float(i) / 26.0
		anchors.append(Vector2(cos(angle) * radii[i], sin(angle) * radii[i] * 0.82))
	return _closed_curve("SmoothIsland", anchors)

## A hand-drawn-looking coastline: 40 anchors with alternating reach, so the
## curve turns hard at every other anchor — fjords rather than a smooth bay.
func _wiggly_coast() -> Path2D:
	var anchors := PackedVector2Array()
	for i in 40:
		var angle := TAU * float(i) / 40.0
		var radius := 4200.0 if i % 2 == 0 else 2100.0
		var wobble := 1.0 + 0.18 * sin(angle * 3.0)
		anchors.append(Vector2(cos(angle) * radius * wobble, sin(angle) * radius * wobble * 0.9))
	return _closed_curve("WigglyCoast", anchors)

## Build a closed Curve2D through `anchors` with Catmull-Rom tangents, so the
## runs genuinely bow. Wrapped neighbours, since the loop closes.
func _closed_curve(name: String, anchors: PackedVector2Array) -> Path2D:
	var path := Path2D.new()
	path.name = name
	path.curve = Curve2D.new()
	var count := anchors.size()
	for i in count:
		var previous := anchors[(i - 1 + count) % count]
		var next := anchors[(i + 1) % count]
		var tangent := (next - previous) / 6.0
		path.curve.add_point(anchors[i], -tangent, tangent)
	return path

func _sample_at(path: Path2D, tolerance: float) -> PackedVector2Array:
	var land := _terrain()
	land.coast_tolerance_deg = tolerance
	return land._sample_curve(path)

func _terrain() -> TerrainNetwork:
	var land := TerrainNetwork.new()
	land.mode = TerrainNetwork.Mode.AUTHORED
	return land

func _authored_terrain(path: Path2D, tolerance: float) -> TerrainNetwork:
	var land := _terrain()
	land.coast_tolerance_deg = tolerance
	_add_markers(land)
	land.add_child(_closed_curve("Island", _anchors_of(path)))
	return land

func _anchors_of(path: Path2D) -> PackedVector2Array:
	var anchors := PackedVector2Array()
	for i in path.curve.point_count:
		anchors.append(path.curve.get_point_position(i))
	return anchors

func _generated_terrain() -> TerrainNetwork:
	var land := TerrainNetwork.new()
	land.mode = TerrainNetwork.Mode.GENERATED
	land.land_seed = 5165
	land.coast_corner = 3000.0
	land.coast_ripple = 2000.0
	land.coast_vertices = 0
	_add_markers(land)
	return land

func _add_markers(land: TerrainNetwork) -> void:
	for spec in MAIN_MARKERS:
		var marker := BiomeMarker.new()
		marker.name = spec["name"]
		marker.biome = spec["biome"]
		marker.position = spec["pos"]
		land.add_child(marker)

## Worst distance from any point of `reference` to the polyline `other`, i.e.
## how far the cheap polygon can sit off the true curve, in pixels.
func _max_deviation(reference: PackedVector2Array, other: PackedVector2Array) -> float:
	var worst := 0.0
	for point in reference:
		var best := INF
		for i in other.size():
			best = minf(best, _point_segment_distance(point, other[i], other[(i + 1) % other.size()]))
		worst = maxf(worst, best)
	return worst

func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	return point.distance_to(a + ab * clampf((point - a).dot(ab) / length_squared, 0.0, 1.0))

func _perimeter(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size():
		total += points[i].distance_to(points[(i + 1) % points.size()])
	return total

func _extent(points: PackedVector2Array) -> float:
	var reach := 0.0
	for point in points:
		reach = maxf(reach, absf(point.x))
		reach = maxf(reach, absf(point.y))
	return reach * 1.4

func _points(band: Array[PackedVector2Array]) -> int:
	var total := 0
	for poly in band:
		total += poly.size()
	return total

func _time_ms(runs: int, body: Callable) -> float:
	body.call()
	var start := Time.get_ticks_usec()
	for _i in runs:
		body.call()
	return float(Time.get_ticks_usec() - start) / float(runs) / 1000.0
