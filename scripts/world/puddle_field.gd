class_name PuddleField
extends Node2D
## The rain's standing water: a scatter of flat puddle shapes laid out along
## the road network, which fade in once `Weather` has soaked the ground and
## fade away again as it dries.
##
## **Art style** follows the composed houses/trees and the junkyard's dirt
## mound: flat fills only, no outlines, no gloss tricks. A puddle is a
## squashed irregular blob of dark water in the road's own asphalt colour
## family, plus a single flat highlight streak suggesting reflected sky.
##
## **Draw order.** Park this between the skid marks and the y-sorted world
## (`main.tscn` has it as a plain root sibling, right after `SkidMarks`), so
## puddles paint over rubber marks on the tarmac but under every car and
## building.
##
## Puddles are placed deterministically from `puddle_seed`, so the same map
## always has the same puddles in the same spots — only their visibility
## changes with the weather.
##
## `is_on_puddle()` is the driving query `PlayerCar` calls every physics frame,
## so it's a uniform-grid bucket lookup with an exact ellipse test on the few
## candidates in one cell, not a scan of every puddle (the same broad-phase
## trick `RoadNetwork.is_on_road` uses).

## How many points each puddle blob is drawn with. Low on purpose — an
## irregular polygon, not a circle.
const PUDDLE_POINTS := 14
## Cell size of the `is_on_puddle` broad phase.
const CELL_SIZE := 128.0
## The fade at which puddles start counting as slippery. Below this the water
## is barely drawn, so it shouldn't grab the car.
const SLIP_FADE := 0.25

@export_group("Layout")
## Seed for the scatter. Change it for a different set of puddles.
@export var puddle_seed: int = 7019
## Distance along a road between candidate spots, re-rolled each step.
@export var spacing_min: float = 360.0
@export var spacing_max: float = 940.0
## Chance a candidate spot is skipped, to thin the scatter unevenly.
@export_range(0.0, 1.0) var skip_chance: float = 0.3
## Puddles never sit closer together than this, so they don't merge into one
## lake across a junction.
@export var min_spacing: float = 150.0
## Hard ceiling on how many puddles the map gets.
@export var max_puddles: int = 130
## How far past the tarmac a puddle's edge may reach, so it can lap onto the
## shoulder without ever pooling on the grass.
@export var edge_margin: float = 18.0
## Puddle size. A puddle is this wide across the road and `squash` of it long
## along the road.
@export var radius_min: float = 42.0
@export var radius_max: float = 78.0

@export_group("Colors")
## Standing water on dark asphalt — deliberately *lighter* than the road and
## picking up the same blue-green as `water.gd`, because a darker patch just
## reads as a hole in the tarmac rather than as water.
@export var water_color: Color = Color(0.29, 0.52, 0.62, 0.85)
## Flat highlight streak inside the puddle, standing in for a skylight
## reflection. No outline and no gradient — just a lighter fill, kept faint so
## it reads as a hint of sky rather than as a patch of paint.
@export var sheen_color: Color = Color(0.88, 0.96, 0.99, 0.16)

@export_group("Sources")
## Where the roads come from, by exported path or (failing that) the first
## `RoadNetwork` anywhere in the scene — same resolution `TrashSpawner` uses.
@export var roads_path: NodePath = ^"../Roads"
## Areas puddles must stay out of. Defaults to the drag strip, whose asphalt
## starts at world x 1800 and whose races are separate scenes anyway.
@export var keep_out_areas: Array[Rect2] = [Rect2(1720.0, -560.0, 3300.0, 1120.0)]

## One Dictionary per puddle: pos, radius, squash, angle, phase.
var _puddles: Array = []
## Vector2i cell -> PackedInt32Array of puddle indices whose bounds cover it.
var _cells: Dictionary = {}
var _built: bool = false
## Current visibility, eased from Weather's wetness. Also gates `is_on_puddle`.
var _fade: float = 0.0

func _ready() -> void:
	# Deferred so the road network is guaranteed to exist and be built, and so
	# the scatter never runs while the scene is still setting up its children.
	build.call_deferred()

func _process(_delta: float) -> void:
	# Only redraw when the fade actually moves — during a dry spell this does
	# nothing at all, and during a shower it's one redraw per visible step.
	var target := clampf((Weather.get_wetness() - 0.05) / 0.45, 0.0, 1.0)
	if absf(target - _fade) > 0.004:
		_fade = target
		queue_redraw()

## Lay out every puddle. Safe to call again — it clears what it made first.
func build() -> void:
	_built = true
	_puddles.clear()
	_cells.clear()
	var roads := _resolve_roads()
	if roads == null:
		push_warning("PuddleField: no RoadNetwork found, so no puddles were placed.")
		return
	roads.ensure_built()

	var rng := RandomNumberGenerator.new()
	rng.seed = puddle_seed
	var placed: Array[Vector2] = []
	for road in roads.get_road_polylines():
		var length := _polyline_length(road)
		if length < 200.0:
			continue
		var travelled := rng.randf_range(spacing_min, spacing_max)
		while travelled < length and _puddles.size() < max_puddles:
			var sample := _sample_along(road, travelled)
			travelled += rng.randf_range(spacing_min, spacing_max)
			if rng.randf() < skip_chance:
				continue
			var point: Vector2 = sample[0]
			var direction: Vector2 = sample[1]
			if direction.length_squared() <= 0.0:
				continue
			var normal := direction.normalized().orthogonal()
			# Roll the size first: a puddle's edge may only lap `edge_margin`
			# past the tarmac, so the bigger the blob the closer to the middle
			# of the road it has to sit.
			var radius := rng.randf_range(radius_min, radius_max)
			var offset_max := maxf(roads.road_width * 0.5 + edge_margin - radius, 0.0)
			var spot: Vector2 = point + normal * rng.randf_range(-offset_max, offset_max)
			if _too_close(spot, placed) or _in_keep_out(spot):
				continue
			placed.append(spot)
			_puddles.append(_make_puddle(spot, normal.angle(), radius, rng))

	_build_index()
	queue_redraw()

## True when `point` is standing in a puddle that's actually showing. Cheap
## enough for a per-physics-frame call: one bucket lookup plus an ellipse test.
func is_on_puddle(point: Vector2) -> bool:
	if _fade < SLIP_FADE:
		return false
	if not _built:
		# Self-heal if the car asked before the deferred build ran.
		build()
	var key := Vector2i((point / CELL_SIZE).floor())
	var candidates: PackedInt32Array = _cells.get(key, PackedInt32Array())
	for index in candidates:
		var puddle: Dictionary = _puddles[index]
		var radius: float = puddle["radius"]
		var local: Vector2 = point - (puddle["pos"] as Vector2)
		local = local.rotated(-(puddle["angle"] as float))
		var ry := radius * (puddle["squash"] as float)
		if (local.x * local.x) / (radius * radius) + (local.y * local.y) / (ry * ry) <= 1.0:
			return true
	return false

## One puddle record. `angle` is the road's direction there, so the blob's long
## axis lies along the road like standing water in a rut would.
func _make_puddle(spot: Vector2, angle: float, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"pos": spot,
		"radius": radius,
		"squash": rng.randf_range(0.45, 0.72),
		"angle": angle + rng.randf_range(-0.25, 0.25),
		"phase": rng.randf_range(0.0, TAU),
	}

## Bucket every puddle into the grid cells its bounding box covers. A cell's
## list is a superset of what could be under a point in it, so the exact test
## only has to run on a handful of candidates.
func _build_index() -> void:
	var buckets: Dictionary = {}
	for i in _puddles.size():
		var puddle: Dictionary = _puddles[i]
		# The blob's radius is drawn up to ~1.15x the stored radius by its
		# wobble, so bucket the bounding circle rather than the bare radius.
		var reach: float = (puddle["radius"] as float) * 1.25
		var pos: Vector2 = puddle["pos"]
		var first := Vector2i(((pos - Vector2(reach, reach)) / CELL_SIZE).floor())
		var last := Vector2i(((pos + Vector2(reach, reach)) / CELL_SIZE).floor())
		for cx in range(first.x, last.x + 1):
			for cy in range(first.y, last.y + 1):
				var key := Vector2i(cx, cy)
				if buckets.has(key):
					buckets[key].append(i)
				else:
					buckets[key] = [i]
	for key in buckets:
		_cells[key] = PackedInt32Array(buckets[key])

func _draw() -> void:
	if _fade <= 0.01:
		return
	for puddle in _puddles:
		_draw_puddle(puddle)

## One flat water blob plus one flat highlight, both authored the same way the
## houses and trees are: solid fills, no outlines.
func _draw_puddle(puddle: Dictionary) -> void:
	var pos: Vector2 = puddle["pos"]
	var radius: float = puddle["radius"]
	var squash: float = puddle["squash"]
	var angle: float = puddle["angle"]
	var phase: float = puddle["phase"]

	var body := PackedVector2Array()
	body.resize(PUDDLE_POINTS)
	for i in PUDDLE_POINTS:
		var a := TAU * float(i) / float(PUDDLE_POINTS)
		# Two harmonics off the blob's own phase: the outline wanders without
		# ever becoming a circle or a blob twice the same shape.
		var wobble := 1.0 + 0.16 * sin(a * 3.0 + phase) + 0.07 * sin(a * 5.0 - phase * 1.7)
		var local := Vector2(cos(a) * radius * wobble, sin(a) * radius * squash * wobble)
		body[i] = pos + local.rotated(angle)
	var fill := water_color
	fill.a *= _fade
	draw_colored_polygon(body, fill)

	# A single elongated streak offset to one side, reading as the sky
	# reflected in the water. Deliberately off-centre — a concentric lighter
	# blob would read as a ring, not a reflection.
	var sheen := PackedVector2Array()
	sheen.resize(8)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var local := Vector2(cos(a) * radius * 0.45, sin(a) * radius * squash * 0.16)
		sheen[i] = pos + (local + Vector2(-radius * 0.26, -radius * squash * 0.3)).rotated(angle)
	var gloss := sheen_color
	gloss.a *= _fade
	draw_colored_polygon(sheen, gloss)

func _too_close(spot: Vector2, placed: Array[Vector2]) -> bool:
	for other in placed:
		if spot.distance_to(other) < min_spacing:
			return true
	return false

func _in_keep_out(point: Vector2) -> bool:
	for area in keep_out_areas:
		if area.has_point(point):
			return true
	return false

## The road network to lay puddles on, by the exported path or, failing that,
## the first one anywhere in the scene.
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

## Total length of a polyline.
func _polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

## The point and unit direction at `distance` along a polyline, by walking its
## segments. Returns [Vector2.ZERO, Vector2.ZERO] if it runs off the end.
func _sample_along(points: PackedVector2Array, distance: float) -> Array:
	var remaining := distance
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segment := a.distance_to(b)
		if segment <= 0.0:
			continue
		if remaining <= segment:
			var t := remaining / segment
			return [a.lerp(b, t), (b - a).normalized()]
		remaining -= segment
	return [Vector2.ZERO, Vector2.ZERO]
