class_name RoadGraph
extends RefCounted
## The road network as something a vehicle can drive: one RoadTrack per road,
## with every place roads meet marked as a stop on each road through it. That
## covers two road ends meeting, a road ending on the middle of another (a
## T-junction), two roads crossing, and a road looping back onto itself. A
## driver can then turn off wherever roads really meet, and only a road end
## with nothing there is a dead end.
##
## Built once per RoadNetwork and shared by every vehicle on it.

## Road ends and crossings this close together are one junction.
const JOIN_RADIUS := 90.0
## Bucket size for the crossing search, so only nearby segments get tested.
const CROSSING_CELL := 512.0
const META := &"road_graph"

## One place roads meet. `exits` holds {road: RoadTrack, station: float}, one
## for every road through it, and each can be driven either way that has road left.
class Junction:
	var exits: Array[Dictionary] = []

var tracks: Array[RoadTrack] = []

static func for_network(network: RoadNetwork) -> RoadGraph:
	if network.has_meta(META):
		return network.get_meta(META)
	network.ensure_built()
	var graph := RoadGraph.new(network.get_draw_polylines())
	network.set_meta(META, graph)
	return graph

func _init(polylines: Array[PackedVector2Array]) -> void:
	for line in polylines:
		if line.size() >= 2:
			tracks.append(RoadTrack.new(line))
	var meetings: Array[Array] = []
	_find_end_joins(meetings)
	_find_crossings(meetings)
	_build_junctions(meetings)

## Each meeting is a list of {road, station} that touch at one spot. A road
## end touching any part of any road — another road's end, its middle, or
## further along its own length — is one.
func _find_end_joins(meetings: Array[Array]) -> void:
	for road in tracks:
		for station: float in [0.0, road.length]:
			var point := road.sample(station)
			for other in tracks:
				var found := _closest_station(other, point, road == other, station)
				if found >= 0.0:
					meetings.append([
						{"road": road, "station": station},
						{"road": other, "station": found}])

## Arc length on `road` closest to `point` if it's within JOIN_RADIUS, else
## -1. On the road's own track, the stretch right by `own_station` is left out.
func _closest_station(road: RoadTrack, point: Vector2, is_own: bool, own_station: float) -> float:
	var from := 0.0
	var to := road.length
	if is_own:
		var skip := JOIN_RADIUS * 2.0
		if road.length <= skip * 2.0:
			return -1.0
		from = skip if own_station <= 0.0 else 0.0
		to = road.length if own_station <= 0.0 else road.length - skip
	var found := road.closest_travelled(point, (from + to) * 0.5, (to - from) * 0.5)
	if is_own and absf(found - own_station) < JOIN_RADIUS * 2.0:
		return -1.0
	return found if road.sample(found).distance_to(point) <= JOIN_RADIUS else -1.0

## Two roads crossing mid-way, or a road crossing itself.
func _find_crossings(meetings: Array[Array]) -> void:
	var cells := {}
	for road_index in tracks.size():
		var road := tracks[road_index]
		for i in road.points.size() - 1:
			var a := road.points[i]
			var b := road.points[i + 1]
			var low := (a.min(b) / CROSSING_CELL).floor()
			var high := (a.max(b) / CROSSING_CELL).floor()
			for x in range(int(low.x), int(high.x) + 1):
				for y in range(int(low.y), int(high.y) + 1):
					var key := Vector2i(x, y)
					if not cells.has(key):
						cells[key] = []
					cells[key].append(Vector2i(road_index, i))
	var tested := {}
	for bucket: Array in cells.values():
		for m in bucket.size():
			for n in range(m + 1, bucket.size()):
				var first: Vector2i = bucket[m]
				var second: Vector2i = bucket[n]
				var pair := Vector4i(first.x, first.y, second.x, second.y) if first < second \
						else Vector4i(second.x, second.y, first.x, first.y)
				if tested.has(pair):
					continue
				tested[pair] = true
				_test_crossing(first, second, meetings)

func _test_crossing(first: Vector2i, second: Vector2i, meetings: Array[Array]) -> void:
	var road_a := tracks[first.x]
	var road_b := tracks[second.x]
	var a1 := road_a.points[first.y]
	var b1 := road_b.points[second.y]
	var hit: Variant = Geometry2D.segment_intersects_segment(
			a1, road_a.points[first.y + 1], b1, road_b.points[second.y + 1])
	if hit == null:
		return
	var point: Vector2 = hit
	var station_a := road_a.distances[first.y] + a1.distance_to(point)
	var station_b := road_b.distances[second.y] + b1.distance_to(point)
	if road_a == road_b and absf(station_a - station_b) < JOIN_RADIUS * 2.0:
		return
	meetings.append([
		{"road": road_a, "station": station_a},
		{"road": road_b, "station": station_b}])

## Meetings close together merge into one junction (a road end touching a
## road also crosses it, three roads meet at one spot, ...). Each road through
## it gets one exit there, and a stop at that station.
func _build_junctions(meetings: Array[Array]) -> void:
	var group := range(meetings.size())
	for m in meetings.size():
		for n in range(m + 1, meetings.size()):
			if _meetings_touch(meetings[m], meetings[n]):
				var from: int = _group_root(group, n)
				var to: int = _group_root(group, m)
				group[from] = to
	var junctions := {}
	for m in meetings.size():
		var root: int = _group_root(group, m)
		if not junctions.has(root):
			junctions[root] = Junction.new()
		var junction: Junction = junctions[root]
		for entry: Dictionary in meetings[m]:
			if not _has_exit_near(junction, entry):
				junction.exits.append(entry)
	for junction: Junction in junctions.values():
		for exit in junction.exits:
			var road: RoadTrack = exit["road"]
			road.stops.append({"station": exit["station"], "junction": junction})
	for road in tracks:
		road.stops.sort_custom(func(a, b): return a["station"] < b["station"])

func _meetings_touch(first: Array, second: Array) -> bool:
	for a: Dictionary in first:
		for b: Dictionary in second:
			if _entry_point(a).distance_to(_entry_point(b)) <= JOIN_RADIUS:
				return true
	return false

func _has_exit_near(junction: Junction, entry: Dictionary) -> bool:
	for exit in junction.exits:
		if exit["road"] == entry["road"] \
				and absf(exit["station"] - entry["station"]) < JOIN_RADIUS * 2.0:
			return true
	return false

static func _entry_point(entry: Dictionary) -> Vector2:
	return (entry["road"] as RoadTrack).sample(entry["station"])

static func _group_root(group: Array, index: int) -> int:
	while group[index] != index:
		index = group[index]
	return index
