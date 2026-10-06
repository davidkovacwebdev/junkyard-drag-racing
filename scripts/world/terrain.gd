@tool
class_name TerrainNetwork
extends Node2D
## Islands for the world map. Everything that isn't listed here is water (see
## `water.gd`), so this node *is* the land. In the running game every shoreline
## is also a static collision outline, so the car can't drive out to sea.
##
## Same two ways of working as the road network:
##
## **Generated** (`mode = GENERATED`) grows a mainland from `land_seed`. The
## mainland is built to *contain* `land_bounds`: its outline starts as that
## rectangle with the corners rounded, densified to `coast_vertices`, pushed out
## by `coast_margin`, and only then wobbled by `coast_ripple` — outward only —
## so however the ripple falls, the city inside the bounds always has ground
## under it. `extra_islands` drops smaller ones in open water for the horizon.
##
## **Authored** is the one to reach for when shaping coastlines by hand: add
## `Path2D` children and drag their curve points in the 2D view. The curve is
## read as a **closed** outline (an island), so there's no need to join the last
## point back to the first. It's sampled by curvature rather than at the curve's
## `bake_interval` — see `coast_tolerance_deg` — so a hand-drawn coastline costs
## what its own shape needs and not what its length costs.
##
## This is a `@tool` script, so the land redraws live while you drag — no
## rebuild step. While you *are* dragging it puts up a cheaper stand-in than the
## finished land (see `fast_preview`) and swaps the real thing back in once the
## edits stop, so a map-sized coastline stays draggable.
##
## `COMBINED` draws both, so you can hand-shape a coastline on top of the
## generated mainland.
##
## Every island is painted as flat nested bands — shallow shelf, foam, beach,
## then land — each a polygon offset of the same shoreline, so grass starts
## right at the coast with nothing dark sitting between them. The three water
## bands (shelf/foam/beach) are each offset from their own lightly and
## independently wobbled copy of that shoreline (see `water_band_variance`), so
## they flare and pinch along the coast instead of tracing it as identical
## concentric rings. Bands are computed once per rebuild (not cheap) and
## cached, so `_draw()` is just fills.
##
## **Biomes.** Drop `BiomeMarker` children on the node and the land's colour
## comes from them instead of `land_color`: each marker claims whichever land is
## nearest, Voronoi-style, and the terrain fills each cell with that biome's two
## tones (see `terrain_biome.gd`). No markers means one flat land colour,
## exactly as before. **Nothing but the colour changes** — markers add no
## gameplay, no collision, and no props. The full, unclipped land/inland bands
## are drawn once underneath the biome patches as a seam filler, so a hairline
## gap between two patches at a cell border shows plain land instead of a gap —
## cheaper than clipping a dedicated seam band, since there's one fewer band to
## offset and clip per island.

enum Mode {
	GENERATED, ## Procedural land from `land_seed` only.
	AUTHORED,  ## Closed curves of any `Path2D` children only.
	COMBINED,  ## Both at once.
}

## Where the land comes from. Add `Path2D` children and pick AUTHORED to
## hand-draw coastlines.
@export var mode: Mode = Mode.GENERATED

@export_group("Coast")
## How far the lighter shallow shelf reaches out past the shoreline.
@export var shallow_width: float = 150.0
## Pale foam line where the water meets the sand. Must be under `shallow_width`.
@export var foam_width: float = 78.0
## Sand between the foam and the grass. Must be under `foam_width`.
@export var beach_width: float = 44.0
## How far in from the coast the inland tone starts.
@export var inland_inset: float = 320.0
## How far past the shoreline the car can wade before the sea walls it off.
## Past the foam, so it gets properly out into the water before it's stuck.
@export var wade_depth: float = 260.0
## How much the shallow/foam/beach bands wander in width along the coast
## instead of tracing it as perfect concentric rings — 0 is a clean shrink-wrap,
## 1 is a strong flare. Purely cosmetic: `land`/`inland` (and so biomes and
## `is_on_land`) are always the true, un-wobbled offsets of the coastline.
@export_range(0.0, 1.0) var water_band_variance: float = 0.5

@export_group("Land")
@export var land_seed: int = 5150
## The mainland is grown to enclose this. Leave it around the city and the drag
## strip and the coast will always sit outside everything that's been built.
@export var land_bounds: Rect2 = Rect2(-4700.0, -2500.0, 9600.0, 5000.0)
## Land guaranteed between `land_bounds` and the shoreline.
@export var coast_margin: float = 420.0
## Corner rounding of the mainland, so it reads as an island and not a lot.
@export var coast_corner: float = 900.0
## How far the coastline wanders off its base line, before `coast_jitter` is
## added on top. Applied outward only, so it can never eat into the bounds.
@export var coast_ripple: float = 220.0
## Points put around the mainland before it's wobbled. The straight runs of the
## rounded rectangle carry no vertices of their own, so without this the wobble
## would have nothing to bend and the coast would come out as a clean rectangle.
@export var coast_vertices: int = 240
## How fine the wobble is: the coarse shape's harmonics, then a finer one riding
## on top, then a third even finer one for small coves and snags. All whole
## numbers so the wave meets itself where the angle wraps.
@export var coast_harmonics: Vector3i = Vector3i(3, 7, 17)
## Extra outward-only noise added per vertex, independent of the harmonic wave
## above — a small irregular jitter so the line reads a little hand-drawn
## instead of a clean mathematical curve. 0 disables it.
@export var coast_jitter: float = 40.0
## Smaller islands out in open water. 0 leaves the one big island alone.
@export var extra_islands: int = 2
@export var extra_island_radius: Vector2 = Vector2(420.0, 980.0)
## Open water kept between the mainland's coast and any extra island.
@export var island_gap: float = 900.0

@export_group("Colors")
## Used for the land only when there are no `BiomeMarker` children. Each island
## nudges this slightly on its own; see `island_color_variance`.
@export var land_color: Color = Color("8ea75e")
## Second land tone, further inland. Same caveat as `land_color`.
@export var inland_color: Color = Color("7d9450")
## Shallow shelf in the water ring.
@export var shallow_color: Color = Color("4f97ab")
@export var foam_color: Color = Color("d8ece8")
@export var beach_color: Color = Color("e6d7a8")
## How far each island's land/inland tones drift from the base colours above —
## a small hue/brightness nudge, seeded off the island's own shape, so a
## scatter of islands doesn't read as the same two colours copy-pasted. 0
## disables it and every island matches exactly. Biome colours are untouched —
## `terrain_biome.gd` already owns that palette.
@export_range(0.0, 1.0) var island_color_variance: float = 0.5

@export_group("Biome seam")
## Picks which bends and drift patches the borders get. Change it (or press
## Shuffle) to roll a new layout; the markers and biomes stay put.
@export var biome_seed: int = 0
@export_tool_button("Shuffle biome seed", "RandomNumberGenerator") var shuffle_biome_seed := func() -> void:
	biome_seed = randi() % 100000
	notify_property_list_changed()

## Borders between biomes are bent into long lazy curves by a smooth noise
## field instead of running ruler-straight, and the three-way corners bend with
## them. Both cells share the exact same seam, so there are no gaps or
## overlaps. 0 keeps the straight Voronoi borders.
@export var biome_seam_wobble: float = 480.0
## Width of one bend in the seam, in pixels. Bigger = longer, gentler curves.
@export var biome_seam_wobble_size: float = 1900.0
## Big chunky patches of the neighbouring biome drift across each border, a
## few per screen, mostly large. Built once per rebuild from the marker
## positions, so they're stable between runs and cost nothing per frame.
@export var biome_drifts_enabled: bool = true
## Average gap between drift patches along a border, in pixels.
@export var biome_drift_spacing: float = 1100.0
## How far past its own size a patch can drift from the border, in pixels.
@export var biome_drift_zone: float = 700.0
## Patch radius as (min, max) pixels. Sizes lean toward the max.
@export var biome_drift_size: Vector2 = Vector2(160.0, 560.0)

@export_group("Authored curves")
## How coarsely a `Path2D` child's curve is sampled into a coastline, in
## degrees: the curve is subdivided until every segment's midpoint stays this
## close to the real curve, so curvy stretches get points and straight ones get
## almost none. That keeps the sampled vertex count proportional to the shape's
## complexity instead of its length, which matters because the coast band
## offsets below are superlinear in vertex count — a map-sized island sampled at
## the curve's baked `bake_interval` (5px) arrives as thousands of vertices and
## costs hundreds of ms to build, every frame, while dragging.
##
## 0 falls back to the curve's baked points: exact, and the escape hatch if a
## coastline ever looks too faceted. `0.5`-`2` is a good range — deviation is
## roughly `radius * tolerance^2 / 8` pixels, so 2 degrees is under a pixel on a
## 3000px island. Only affects AUTHORED and COMBINED.
@export_range(0.0, 12.0, 0.1) var coast_tolerance_deg: float = 2.0

@export_group("Editor preview")
## While the editor is open, an edit draws a cheaper version of the land first
## and the full-quality version once the edits stop (see `preview_settle_sec`),
## so dragging a coastline or a biome marker stays responsive on a map-sized
## island. The stand-in drops the three cosmetic water bands and the inland
## inset — three of the island's four polygon offsets, and nearly all of the
## build cost — so it reads as flat, biome-coloured land with a bare coastline.
##
## Only ever affects what the editor draws mid-edit: the saved scene, the
## running game and the band data all use the real thing. Off means every edit
## pays full price, which is what you want when scrubbing a curve small enough
## that the version popping in would be more distracting than the wait.
@export var fast_preview: bool = true
## How coarsely coastlines are sampled while previewing, in degrees. Same units
## as `coast_tolerance_deg`, just coarser: this only has to read as a coastline
## while you're moving it, and fewer vertices is what makes the stand-in cheap.
## The exact coastline is rebuilt on settle.
@export_range(0.5, 24.0, 0.5) var preview_tolerance_deg: float = 6.0
## How long the inputs have to hold still before the full-quality rebuild runs.
## 0 swaps the real land in on the frame after you stop moving.
@export_range(0.0, 3.0, 0.05) var preview_settle_sec: float = 0.5

## Subdivision cap for the sampling above. Generous on purpose: cost is driven
## by `coast_tolerance_deg`, and a sharply curved stretch needs the extra
## stages to reach it at all (a 90-degree turn in one segment takes about six).
const COAST_TESSELLATE_STAGES := 8
## Group on the shoreline's collision body, so the car can tell running into
## the sea apart from bumping a building.
const SHORE_GROUP := &"shore"

## One island's nested bands, outermost first. Painted in this order, so each
## smaller band covers the middle of the one before it and only a ring of that
## band shows. Each is a *list* because shrinking a concave coastline can split
## the interior into several pieces.
class Island:
	## The shoreline itself, kept around for reference; not drawn on its own.
	var coastline: PackedVector2Array = PackedVector2Array()
	## Cosmetic only, each offset from its own independently-wobbled copy of the
	## shoreline (see `water_band_variance`) rather than the shoreline itself.
	var shore: Array[PackedVector2Array] = []
	var foam: Array[PackedVector2Array] = []
	var beach: Array[PackedVector2Array] = []
	## Land starts right at the true coastline — no inset band between the two.
	var land: Array[PackedVector2Array] = []
	## The band running `inland_inset` in from the coast, and the island's
	## interior inside that.
	var inland: Array[PackedVector2Array] = []
	## One entry per biome that reaches this island: that biome's share of the
	## land and inland bands, already clipped and ready to fill.
	var patches: Array[BiomePatch] = []
	## This island's own land/inland tones, nudged from the base colours by
	## `island_color_variance`. Ignored for patches, which use biome colours.
	var land_tint: Color
	var inland_tint: Color

## A biome's slice of one island.
class BiomePatch:
	var biome: int = TerrainBiome.Kind.PLAINS
	var land: Array[PackedVector2Array] = []
	var inland: Array[PackedVector2Array] = []

## A drifted patch of one biome sitting in a neighbour's cell, clipped to it.
class BiomeDrift:
	var biome: int = TerrainBiome.Kind.PLAINS
	var polygon: PackedVector2Array
	var bounds: Rect2

## Every island's bands, ready to draw.
var _islands: Array[Island] = []
## Just the shorelines, for the query API.
var _coastlines: Array[PackedVector2Array] = []
## The biome markers, in the same order as `_cells`.
var _markers: Array[BiomeMarker] = []
## One Voronoi cell per marker, in this node's local space.
var _cells: Array[PackedVector2Array] = []
## Drift patches across every biome border, in draw order.
var _drifts: Array[BiomeDrift] = []
var _wobble_noise_x := FastNoiseLite.new()
var _wobble_noise_y := FastNoiseLite.new()
## Editor-only: snapshot of the inputs, polled so edits get noticed.
var _signature: String = ""
## Editor-only: true while the cheap stand-in is on screen, waiting for the
## edits to stop so the full-quality rebuild can run.
var _draft: bool = false
## Editor-only: seconds the inputs have held still since the last change.
var _settle: float = 0.0

func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		_build_shore_collision()
	if Engine.is_editor_hint():
		# Dragging a Path2D's curve or a biome marker doesn't notify us, so poll
		# a cheap snapshot of the inputs and rebuild when it changes. That's what
		# makes authored coastlines and biome borders follow live.
		_signature = _compute_signature()
		set_process(true)
	else:
		set_process(false)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var signature := _compute_signature()
	if signature != _signature:
		_signature = signature
		# Mid-edit: put the stand-in up and start the settle clock. With
		# previewing off this is just the old full rebuild, every change.
		_draft = fast_preview
		_settle = 0.0
		_rebuild()
		return
	if not _draft:
		return
	# Held still long enough: finish the job at full quality.
	_settle += delta
	if _settle >= preview_settle_sec:
		_draft = false
		_rebuild()

## True while the cheap stand-in is on screen, i.e. mid-edit in the editor.
## Never true in a running game, which only ever builds the real thing.
func _previewing() -> bool:
	return _draft and Engine.is_editor_hint()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var paths := 0
	for child in get_children():
		if child is Path2D:
			paths += 1
	if mode == Mode.GENERATED and paths > 0:
		warnings.append("This node has %d Path2D child(ren), but mode is GENERATED so they are ignored. Switch mode to AUTHORED or COMBINED to draw them." % paths)
	elif mode != Mode.GENERATED and paths == 0:
		warnings.append("mode is %s but there are no Path2D children. Add one and drag its curve points in the 2D view to author coastlines." % Mode.find_key(mode))
	if _markers.size() == 1:
		warnings.append("Only one BiomeMarker, so the whole land is that biomes colour. Add another to start cutting the island up.")
	return warnings

## Rebuild every island from the current inputs. Runs on ready, and again
## whenever the inputs change while the editor is open.
func _rebuild() -> void:
	_islands.clear()
	_coastlines.clear()
	if mode == Mode.GENERATED or mode == Mode.COMBINED:
		for coastline in _generate_land():
			_add_island(coastline)
	if mode == Mode.AUTHORED or mode == Mode.COMBINED:
		for child in get_children():
			if child is Path2D:
				var coastline := _sample_curve(child as Path2D)
				if coastline.size() >= 3:
					_add_island(coastline)
	_collect_markers()
	_build_cells()
	queue_redraw()

## Built once: an outline of segments per coastline, pushed `wade_depth` out to
## sea so the car can roll into the shallows (and get stuck there, see
## `PlayerCar`) but never drive off across the ocean.
func _build_shore_collision() -> void:
	var shore_body := StaticBody2D.new()
	shore_body.name = "ShoreCollision"
	shore_body.add_to_group(SHORE_GROUP)
	for coastline in _coastlines:
		for wall in Geometry2D.offset_polygon(coastline, wade_depth, Geometry2D.JOIN_ROUND):
			var outline := CollisionPolygon2D.new()
			outline.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
			outline.polygon = wall
			shore_body.add_child(outline)
	add_child(shore_body)

func _add_island(coastline: PackedVector2Array) -> void:
	_coastlines.append(coastline)
	_islands.append(_build_island(coastline))

func _collect_markers() -> void:
	_markers.clear()
	for child in get_children():
		if child is BiomeMarker:
			_markers.append(child as BiomeMarker)

## Build one Voronoi cell per marker: the box, cut down by the perpendicular
## bisector against every other marker, so each cell ends up being exactly the
## region nearer its own marker than any other. Cells stay convex the whole way
## through, which is what makes the clipping cheap.
func _build_cells() -> void:
	_cells.clear()
	if _markers.is_empty():
		return
	var box := _cell_bounds()
	for i in _markers.size():
		var cell := box
		for j in _markers.size():
			if i == j:
				continue
			cell = _clip_half_plane(cell, _marker_point(i), _marker_point(j))
			if cell.size() < 3:
				break
		_cells.append(cell)
	_drifts.clear()
	var seams := _wobble_cells()
	if biome_drifts_enabled:
		for pair: Vector2i in seams:
			_scatter_drifts(pair, seams[pair][0], seams[pair][1])
	# Now that the cells exist, slice each island up by them.
	for i in _islands.size():
		_build_patches(_islands[i])

## Subdivide every border shared by two cells, then push every cell corner
## through the wobble field. Each seam is subdivided once per pair and handed to
## both cells, so the two sides always meet exactly. Returns the straight seams,
## pair -> [start, end], for the drift patches to follow.
func _wobble_cells() -> Dictionary:
	var seams := {}
	if biome_seam_wobble <= 0.0:
		for i in _cells.size():
			for k in _cells[i].size():
				var start := _cells[i][k]
				var end := _cells[i][(k + 1) % _cells[i].size()]
				var neighbour := _neighbour_across(i, start, end)
				if neighbour > i:
					seams[Vector2i(i, neighbour)] = [start, end]
		return seams
	_wobble_noise_x.seed = land_seed + biome_seed * 2
	_wobble_noise_y.seed = land_seed + biome_seed * 2 + 1
	for noise in [_wobble_noise_x, _wobble_noise_y]:
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 1.0 / biome_seam_wobble_size
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var step := biome_seam_wobble_size / 8.0
	for i in _cells.size():
		var cell := _cells[i]
		if cell.size() < 3:
			continue
		var wobbled := PackedVector2Array()
		for k in cell.size():
			var start := cell[k]
			var end := cell[(k + 1) % cell.size()]
			wobbled.append(_wobbled(start))
			var neighbour := _neighbour_across(i, start, end)
			if neighbour < 0:
				continue
			var pair := Vector2i(mini(i, neighbour), maxi(i, neighbour))
			if not seams.has(pair):
				seams[pair] = [start, end, _seam_points(start, end, step)]
			var seam_start: Vector2 = seams[pair][0]
			var points: PackedVector2Array = seams[pair][2].duplicate()
			if start.distance_squared_to(seam_start) > end.distance_squared_to(seam_start):
				points.reverse()
			wobbled.append_array(points)
		_cells[i] = wobbled
	return seams

## The wobbled points strictly between `start` and `end`, `step` apart.
func _seam_points(start: Vector2, end: Vector2, step: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := int(ceilf(start.distance_to(end) / step))
	for index in range(1, count):
		points.append(_wobbled(start.lerp(end, float(index) / count)))
	return points

## Where `point` lands once the smooth noise field has pushed it around.
func _wobbled(point: Vector2) -> Vector2:
	if biome_seam_wobble <= 0.0:
		return point
	return point + Vector2(_wobble_noise_x.get_noise_2dv(point), _wobble_noise_y.get_noise_2dv(point)) * biome_seam_wobble

## The cell on the other side of the edge `start`-`end` of cell `index`, or -1
## if the edge is on the outer box.
func _neighbour_across(index: int, start: Vector2, end: Vector2) -> int:
	if start.distance_squared_to(end) < 1.0:
		return -1
	var own := _marker_point(index)
	for other in _markers.size():
		if other == index:
			continue
		var away := _marker_point(other)
		var normal := (away - own).normalized()
		var middle := (own + away) * 0.5
		if absf((start - middle).dot(normal)) < 0.5 and absf((end - middle).dot(normal)) < 0.5:
			return other
	return -1

## Scatter drift patches along the straight seam between the cells in `pair`,
## then push them through the wobble field so they follow the bent seam. Each
## patch sits in one cell wearing the other's colour, kept clear of the seam so
## it never melts into it as a thin spike. Sizes lean large, patches crowd the
## seam, and some get a small satellite chunk further out.
func _scatter_drifts(pair: Vector2i, start: Vector2, end: Vector2) -> void:
	if _markers[pair.x].biome == _markers[pair.y].biome:
		return
	var length := start.distance_to(end)
	if length < 1.0 or biome_drift_spacing <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(_marker_point(pair.x))) ^ (hash(Vector2i(_marker_point(pair.y))) * 31) ^ hash(biome_seed)
	var direction := (end - start) / length
	var along := rng.randf() * biome_drift_spacing * 0.5
	while along < length:
		if rng.randf() < 0.8:
			var host := pair.x if rng.randf() < 0.5 else pair.y
			var guest := pair.y if host == pair.x else pair.x
			var into_host := (_marker_point(host) - _marker_point(guest)).normalized()
			var closeness := pow(rng.randf(), 1.4)
			var radius := lerpf(biome_drift_size.x, biome_drift_size.y, sqrt(rng.randf()))
			radius *= lerpf(1.0, 0.65, closeness)
			var depth := radius * 1.1 + closeness * biome_drift_zone
			var center := _wobbled(start + direction * along + into_host * depth)
			var heading := direction.angle() + rng.randf_range(-0.6, 0.6)
			if rng.randf() < 0.25:
				heading = rng.randf() * TAU
			var biome := _markers[guest].biome
			_add_drift(_drift_shape(center, radius, heading, rng), biome, host, radius)
			if rng.randf() < 0.3:
				var satellite_radius := radius * rng.randf_range(0.3, 0.5)
				var satellite_direction := into_host.rotated(rng.randf_range(-1.0, 1.0))
				var satellite_center := center + satellite_direction * (radius + satellite_radius) * 1.1
				_add_drift(_drift_shape(satellite_center, satellite_radius, rng.randf() * TAU, rng), biome, host, satellite_radius)
		along += biome_drift_spacing * rng.randf_range(0.6, 1.4)

## A chunky 5-8 sided patch, stretched along `heading` by a random amount, so
## some are round blobs and some long drifts.
func _drift_shape(center: Vector2, radius: float, heading: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var corner_count := rng.randi_range(5, 8)
	var stretch := Vector2(rng.randf_range(1.0, 2.2), rng.randf_range(0.6, 1.0))
	var points := PackedVector2Array()
	for corner in corner_count:
		var angle := TAU * (corner + rng.randf_range(-0.3, 0.3)) / corner_count
		var reach := radius * rng.randf_range(0.6, 1.0)
		points.append(center + (Vector2(cos(angle) * stretch.x, sin(angle) * stretch.y) * reach).rotated(heading))
	return points

## Clip a drift patch to its host cell, so it never spills into a third biome.
## Slivers left over from the clip are dropped rather than drawn as crumbs.
func _add_drift(shape: PackedVector2Array, biome: int, host: int, radius: float) -> void:
	for piece in Geometry2D.intersect_polygons(shape, _cells[host]):
		if piece.size() < 3 or _polygon_area(piece) < radius * radius * 0.4:
			continue
		var drift := BiomeDrift.new()
		drift.biome = biome
		drift.polygon = piece
		drift.bounds = Rect2(piece[0], Vector2.ZERO)
		for point in piece:
			drift.bounds = drift.bounds.expand(point)
		_drifts.append(drift)

## Every marker's position in this node's local space. Markers are ordinary
## children, so this keeps working if the terrain node itself is moved or scaled.
func _marker_point(index: int) -> Vector2:
	var marker := _markers[index]
	if is_inside_tree():
		return to_local(marker.global_position)
	return marker.position

## A rectangle that encloses all the land, grown well clear of it. Voronoi cells
## only need to be big enough to cover the islands they'll be clipped against.
func _cell_bounds() -> PackedVector2Array:
	var rect := Rect2(_marker_point(0), Vector2.ZERO)
	for coastline in _coastlines:
		for point in coastline:
			rect = rect.expand(point)
	rect = rect.expand(_marker_point(0))
	var grown := rect.grow(1000.0 + rect.size.length() * 0.1)
	return PackedVector2Array([
		grown.position,
		Vector2(grown.end.x, grown.position.y),
		grown.end,
		Vector2(grown.position.x, grown.end.y),
	])

# --- Queries for other systems -------------------------------------------------

## Build now instead of waiting for `_ready()`. Idempotent, and safe to call
## from a sibling that needs the land already laid out.
func ensure_built() -> void:
	if _islands.is_empty():
		_rebuild()

## Every island's shoreline as a closed polygon in this node's local space.
## Callers should not modify the result — it's the network's own working data.
func get_island_polygons() -> Array[PackedVector2Array]:
	return _coastlines

## True if `point` is on land. Points past a shoreline are water.
func is_on_land(point: Vector2) -> bool:
	for coastline in _coastlines:
		if Geometry2D.is_point_in_polygon(point, coastline):
			return true
	return false

## True if `point` is past the surf, out in the blue. Reads the drawn foam
## band, so it matches where the water visibly starts.
func is_in_water(point: Vector2) -> bool:
	for island in _islands:
		for surf in island.foam:
			if Geometry2D.is_point_in_polygon(point, surf):
				return false
	return true

## Which biome owns the land here, or -1 if there are no markers. Reads the
## cells and drift patches themselves, so it agrees with what's drawn even
## where the point is out at sea; past the cells it falls back to the raw
## nearest-marker rule they are cut from.
func biome_at(point: Vector2) -> int:
	if _markers.is_empty():
		return -1
	for index in range(_drifts.size() - 1, -1, -1):
		var drift := _drifts[index]
		if drift.bounds.has_point(point) and Geometry2D.is_point_in_polygon(point, drift.polygon):
			return drift.biome
	for i in _cells.size():
		if _cells[i].size() >= 3 and Geometry2D.is_point_in_polygon(point, _cells[i]):
			return _markers[i].biome
	var best := INF
	var biome := _markers[0].biome
	for i in _markers.size():
		var distance := point.distance_squared_to(_marker_point(i))
		if distance < best:
			best = distance
			biome = _markers[i].biome
	return biome

# --- Authoring -----------------------------------------------------------------

## Sample a Path2D's curve into a closed outline in this node's space. A
## duplicated last point (a curve drawn back to its own start) is dropped —
## `offset_polygon` and the fills both close the shape on their own.
##
## Sampled by curvature rather than at the curve's `bake_interval`; see
## `coast_tolerance_deg` for why that matters. `coast_tolerance_deg <= 0` keeps
## the old exact behaviour, and is deliberately handled here rather than passed
## to `tessellate()`, where 0 would ask for endless subdivision.
func _sample_curve(path: Path2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var curve := path.curve
	if curve == null:
		return points
	var tolerance := coast_tolerance_deg
	if _previewing():
		# Fewer vertices is what the offsets below are actually expensive in,
		# so the stand-in samples coarser still. A tolerance of 0 (exact,
		# baked) gets the coarse pass too while dragging — the true coastline
		# comes back on settle.
		tolerance = maxf(tolerance, preview_tolerance_deg)
	var source := curve.get_baked_points()
	if tolerance > 0.0:
		source = curve.tessellate(COAST_TESSELLATE_STAGES, tolerance)
	for point in source:
		points.append(path.transform * point)
	if points.size() >= 3 and points[0].is_equal_approx(points[points.size() - 1]):
		points.remove_at(points.size() - 1)
	return points

# --- Generation ----------------------------------------------------------------

## The mainland, plus whatever extra islands the settings ask for.
func _generate_land() -> Array[PackedVector2Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = land_seed
	var bounds := _normalized_bounds()
	var base := _densify(_rounded_rect(bounds.grow(coast_margin), coast_corner), coast_vertices)
	var out: Array[PackedVector2Array] = [_wobble(base, bounds.get_center(), rng)]
	_add_extra_islands(rng, out, bounds)
	return out

## Scatter smaller islands around the mainland, out in open water. Each one is
## placed past that direction's coastline (plus `island_gap`), so they never
## touch the mainland, and kept apart from each other.
func _add_extra_islands(rng: RandomNumberGenerator, out: Array[PackedVector2Array], bounds: Rect2) -> void:
	if extra_islands <= 0:
		return
	var center := bounds.get_center()
	var shelf := bounds.grow(coast_margin)
	var placed: Array[Vector2] = []
	var min_gap := extra_island_radius.y * 2.0 + island_gap
	for _i in extra_islands:
		var radius := rng.randf_range(extra_island_radius.x, extra_island_radius.y)
		for _attempt in 24:
			var angle := rng.randf_range(0.0, TAU)
			var direction := Vector2(cos(angle), sin(angle))
			# Coastline along this direction, then clear water, then the island.
			var reach := _rect_ray_exit(shelf, direction) + coast_ripple + island_gap + radius
			var spot := center + direction * reach
			var clear := true
			for other in placed:
				if spot.distance_to(other) < min_gap:
					clear = false
					break
			if not clear:
				continue
			placed.append(spot)
			out.append(_blob(spot, radius, rng))
			break

## A rounded rectangle, sampled as a polygon: one arc per corner, with the
## straight runs left implicit (the fill joins them anyway).
func _rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(r, r), PI, PI * 1.5],                    ## Top-left.
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5, TAU],    ## Top-right.
		[rect.end - Vector2(r, r), 0.0, PI * 0.5],                        ## Bottom-right.
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],     ## Bottom-left.
	]
	var steps := 8
	var points := PackedVector2Array()
	for corner in corners:
		var center: Vector2 = corner[0]
		var from: float = corner[1]
		var to: float = corner[2]
		for i in steps + 1:
			var angle := lerpf(from, to, float(i) / float(steps))
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points

## Evenly space `count` vertices around a closed loop, so a shape built from
## long straight runs (a rounded rectangle) still has enough points for the
## wobble to actually bend it.
func _densify(points: PackedVector2Array, count: int) -> PackedVector2Array:
	if points.size() < 2 or count <= points.size():
		return points
	var lengths := PackedFloat32Array()
	var total := 0.0
	for i in points.size():
		var length := points[i].distance_to(points[(i + 1) % points.size()])
		lengths.append(length)
		total += length
	if total <= 0.0:
		return points
	var out := PackedVector2Array()
	var step := total / float(count)
	var travelled := 0.0
	var target := 0.0
	var index := 0
	var walked := 0.0
	for _i in count:
		while index < points.size() and walked + lengths[index] < target:
			walked += lengths[index]
			index += 1
		if index >= points.size():
			break
		var t := 0.0 if lengths[index] <= 0.0 else (target - walked) / lengths[index]
		out.append(points[index].lerp(points[(index + 1) % points.size()], t))
		travelled += step
		target = travelled
	return out

## Push every vertex of a closed outline outward, away from `center`, by up to
## `coast_ripple`, then add a small independent per-vertex jitter on top (see
## `coast_jitter`). The harmonic wave is keyed on the vertex's angle around the
## island and the harmonics are whole numbers, so it meets itself where the
## loop closes instead of leaving a seam; the jitter has no such constraint
## since it's per-vertex noise rather than a continuous wave, but it's small
## enough not to read as one either. **Outward only, in total** — the shape can
## only grow, which is what keeps the mainland a guaranteed home for everything
## inside `land_bounds`.
func _wobble(points: PackedVector2Array, center: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	if coast_ripple <= 0.0 and coast_jitter <= 0.0:
		return points
	var coarse := maxi(coast_harmonics.x, 1)
	var fine := maxi(coast_harmonics.y, coarse + 1)
	var detail := maxi(coast_harmonics.z, fine + 1)
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	var phase_c := rng.randf_range(0.0, TAU)
	var out := PackedVector2Array()
	for point in points:
		var offset := point - center
		if offset.length_squared() <= 0.0:
			out.append(point)
			continue
		var angle := offset.angle()
		# 0.5 + 0.25 + 0.15 + 0.1 tops out at 1.0 and bottoms out at 0.0.
		var wave := 0.5 \
				+ 0.25 * sin(angle * coarse + phase_a) \
				+ 0.15 * sin(angle * fine + phase_b) \
				+ 0.10 * sin(angle * detail + phase_c)
		var jitter := rng.randf_range(0.0, coast_jitter)
		out.append(point + offset.normalized() * (coast_ripple * wave + jitter))
	return out

## An irregular round island. Harmonic counts and amplitudes are drawn from
## `rng` rather than fixed, so a scatter of these doesn't read as the same
## template stamped out at different sizes.
func _blob(center: Vector2, radius: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var steps := 40
	var coarse := rng.randi_range(3, 4)
	var fine := rng.randi_range(coarse + 2, coarse + 4)
	var coarse_amount := rng.randf_range(0.10, 0.18)
	var fine_amount := rng.randf_range(0.05, 0.10)
	var phase_a := rng.randf_range(0.0, TAU)
	var phase_b := rng.randf_range(0.0, TAU)
	var squash := rng.randf_range(0.7, 1.0)
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := TAU * float(i) / float(steps)
		var r := radius * (1.0 + coarse_amount * sin(angle * coarse + phase_a) + fine_amount * sin(angle * fine + phase_b))
		points.append(center + Vector2(cos(angle) * r, sin(angle) * r * squash))
	return points

## Distance from a rect's centre out to its edge along `direction` — i.e. how
## far open water runs that way. Zero for a degenerate direction.
func _rect_ray_exit(rect: Rect2, direction: Vector2) -> float:
	var half := rect.size * 0.5
	var reach := INF
	if absf(direction.x) > 0.0001:
		reach = minf(reach, half.x / absf(direction.x))
	if absf(direction.y) > 0.0001:
		reach = minf(reach, half.y / absf(direction.y))
	return 0.0 if reach == INF else reach

func _normalized_bounds() -> Rect2:
	var rect := land_bounds
	if rect.size.x < 0.0:
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	if rect.size.y < 0.0:
		rect.position.y += rect.size.y
		rect.size.y = -rect.size.y
	return rect

# --- Band building -------------------------------------------------------------

## Grow and shrink one shoreline into the island's drawn bands. `land` is the
## coastline itself — no inset gap for a coastal underlay to show through — and
## `inland` is a single further negative offset from it. The three cosmetic
## water bands are each offset from their own independently-wobbled copy of the
## shoreline (`_wavy_source`), computed off one shared set of per-vertex
## normals so that setup cost is paid once per island, not three times.
##
## While previewing, only `land` is filled: the offsets are exactly what a drag
## can't afford; see `fast_preview`.
func _build_island(coastline: PackedVector2Array) -> Island:
	var island := Island.new()
	island.coastline = coastline
	island.land.append(coastline)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coastline)
	if _previewing():
		# Stand-in while dragging: no offset bands at all. The inland inset and
		# all three wavy water bands are skipped, leaving flat biome-coloured
		# land — enough to see a coastline move. Tints are seeded off this
		# same (coarser) coastline, so they can land slightly differently here
		# than they will on settle; cosmetic, and only up for a frame or two.
		island.land_tint = _tinted(land_color, rng)
		island.inland_tint = _tinted(inland_color, rng)
		return island
	island.inland = Geometry2D.offset_polygon(coastline, -inland_inset, Geometry2D.JOIN_ROUND)
	if water_band_variance > 0.0:
		var normals := _outward_normals(coastline)
		island.shore = Geometry2D.offset_polygon(
				_wavy_source(coastline, normals, shallow_width, rng), maxf(shallow_width, 1.0), Geometry2D.JOIN_ROUND)
		island.foam = Geometry2D.offset_polygon(
				_wavy_source(coastline, normals, foam_width, rng), maxf(foam_width, 1.0), Geometry2D.JOIN_ROUND)
		island.beach = Geometry2D.offset_polygon(
				_wavy_source(coastline, normals, beach_width, rng), maxf(beach_width, 1.0), Geometry2D.JOIN_ROUND)
	else:
		island.shore = Geometry2D.offset_polygon(coastline, maxf(shallow_width, 1.0), Geometry2D.JOIN_ROUND)
		island.foam = Geometry2D.offset_polygon(coastline, maxf(foam_width, 1.0), Geometry2D.JOIN_ROUND)
		island.beach = Geometry2D.offset_polygon(coastline, maxf(beach_width, 1.0), Geometry2D.JOIN_ROUND)
	island.land_tint = _tinted(land_color, rng)
	island.inland_tint = _tinted(inland_color, rng)
	return island

## A copy of `coastline` pushed outward, per vertex, along that vertex's
## precomputed `normals` by a random amount up to `width * water_band_variance
## * 0.5`. Used only as the input to a water band's own `offset_polygon` call,
## so a band can flare wide in one stretch and pinch narrow in another instead
## of holding a fixed width all the way round. Outward only relative to the
## true coastline, so these bands can widen but never narrow past it.
func _wavy_source(coastline: PackedVector2Array, normals: PackedVector2Array, width: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var magnitude := width * water_band_variance * 0.5
	var out := PackedVector2Array()
	for i in coastline.size():
		out.append(coastline[i] + normals[i] * rng.randf_range(0.0, magnitude))
	return out

## The outward-facing normal at every vertex of a closed polygon, found from
## each vertex's neighbours rather than from a centre point — unlike `_wobble`,
## this has to stay correct for concave stretches of coastline and for extra
## islands that sit far from any one shared centre. Computed once per island
## and shared by all three water bands.
func _outward_normals(points: PackedVector2Array) -> PackedVector2Array:
	var n := points.size()
	var normals := PackedVector2Array()
	normals.resize(n)
	var signed_area := 0.0
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		signed_area += a.x * b.y - b.x * a.y
	# Godot's Y axis points down, so a positive signed area is a clockwise
	# loop; the outward normal then needs the opposite rotation from the
	# usual CCW convention.
	var sign := -1.0 if signed_area > 0.0 else 1.0
	for i in n:
		var prev := points[(i - 1 + n) % n]
		var next := points[(i + 1) % n]
		var tangent := next - prev
		if tangent.length_squared() <= 0.0001:
			normals[i] = Vector2.ZERO
			continue
		tangent = tangent.normalized()
		normals[i] = Vector2(-tangent.y, tangent.x) * sign
	return normals

## Nudge `base` a little, deterministically, off `island_color_variance`. Hue
## drifts by at most a tenth of the variance (a full swing would drift the
## palette off-model), saturation and value by the full amount — enough to
## tell islands apart without any of them looking like a different biome.
func _tinted(base: Color, rng: RandomNumberGenerator) -> Color:
	if island_color_variance <= 0.0:
		return base
	var hue := fmod(base.h + rng.randf_range(-1.0, 1.0) * island_color_variance * 0.1 + 1.0, 1.0)
	var sat := clampf(base.s + rng.randf_range(-1.0, 1.0) * island_color_variance * 0.12, 0.0, 1.0)
	var val := clampf(base.v + rng.randf_range(-1.0, 1.0) * island_color_variance * 0.1, 0.0, 1.0)
	return Color.from_hsv(hue, sat, val, base.a)

## Slice one island's bands up by the Voronoi cells: each biome keeps the part
## of the land and the inland band that falls inside its own cell.
func _build_patches(island: Island) -> void:
	island.patches.clear()
	for i in _cells.size():
		if _cells[i].size() < 3:
			continue
		var patch := BiomePatch.new()
		patch.biome = _markers[i].biome
		patch.land = _clip_to(_cells[i], island.land)
		patch.inland = _clip_to(_cells[i], island.inland)
		if patch.land.is_empty():
			continue
		island.patches.append(patch)
	var island_bounds := Rect2(island.coastline[0], Vector2.ZERO)
	for point in island.coastline:
		island_bounds = island_bounds.expand(point)
	for drift in _drifts:
		if not drift.bounds.intersects(island_bounds):
			continue
		var patch := BiomePatch.new()
		patch.biome = drift.biome
		patch.land = _clip_to(drift.polygon, island.land)
		patch.inland = _clip_to(drift.polygon, island.inland)
		if patch.land.is_empty():
			continue
		island.patches.append(patch)

func _polygon_area(polygon: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in polygon.size():
		twice_area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(twice_area) * 0.5

## A cell's share of every polygon in a band, as a flat list of pieces.
func _clip_to(cell: PackedVector2Array, band: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for polygon in band:
		out.append_array(Geometry2D.intersect_polygons(cell, polygon))
	return out

## Cut a convex polygon down to the half of it nearer `keep` than `away`.
## Sutherland–Hodgman against one line, which is all a Voronoi cell is.
func _clip_half_plane(polygon: PackedVector2Array, keep: Vector2, away: Vector2) -> PackedVector2Array:
	var offset := away - keep
	var length := offset.length()
	if length <= 0.0001:
		return polygon
	var normal := offset / length
	var mid := (keep + away) * 0.5
	var out := PackedVector2Array()
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var side_a := (a - mid).dot(normal)
		var side_b := (b - mid).dot(normal)
		if side_a <= 0.0:
			out.append(a)
		if (side_a <= 0.0) != (side_b <= 0.0):
			out.append(a.lerp(b, side_a / (side_a - side_b)))
	return out

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	for island in _islands:
		_fill(island.shore, shallow_color)
		_fill(island.foam, foam_color)
		_fill(island.beach, beach_color)
		if island.patches.is_empty():
			_fill(island.land, island.land_tint)
			_fill(island.inland, island.inland_tint)
			continue
		# Full, unclipped bands first as a seam filler (see the class doc),
		# then each biome's own slice on top.
		_fill(island.land, island.land_tint)
		_fill(island.inland, island.inland_tint)
		for patch in island.patches:
			_fill(patch.land, TerrainBiome.edge_color(patch.biome, 0.0))
		for patch in island.patches:
			_fill(patch.inland, TerrainBiome.base_color(patch.biome))

func _fill(polygons: Array[PackedVector2Array], color: Color) -> void:
	for polygon in polygons:
		if polygon.size() >= 3:
			draw_colored_polygon(polygon, color)

# --- Editor polling ------------------------------------------------------------

## Cheap snapshot of every input `_rebuild()` depends on. Compared each editor
## frame to notice curve and marker edits (and inspector changes) and rebuild.
func _compute_signature() -> String:
	var parts := PackedStringArray()
	for value in [mode, land_seed, land_bounds, coast_margin, coast_corner,
			coast_ripple, coast_vertices, coast_harmonics, coast_jitter,
			extra_islands, extra_island_radius, island_gap, shallow_width,
			foam_width, beach_width, inland_inset, water_band_variance,
			island_color_variance, shallow_color, foam_color, beach_color,
			land_color, inland_color, coast_tolerance_deg, fast_preview,
			preview_tolerance_deg, preview_settle_sec, biome_seam_wobble,
			biome_seam_wobble_size, biome_drifts_enabled, biome_drift_spacing,
			biome_drift_zone, biome_drift_size, biome_seed]:
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
		elif child is BiomeMarker:
			var marker := child as BiomeMarker
			parts.append(str(marker.name, marker.biome, marker.transform))
	return "|".join(parts)
