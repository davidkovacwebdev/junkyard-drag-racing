class_name RoadRoute
extends RefCounted
## Finds a way along the roads from one spot on the map to another, for
## someone to drive it (Grandpa's wheelchair in "Fish Supper", DinnerStory).
## The roads are sampled every `STEP` px into a graph: neighbours along a road
## are linked, and so are samples of different roads that come within
## `JOIN` px of each other (where they cross or meet). Built once per road
## network.

const STEP := 120.0
const JOIN := 100.0

static var _graph: AStar2D = null
static var _built_for: WeakRef = null

## The points to drive through, `from` and `to` included. Just the two of
## them if there's no road network.
static func find(roads: RoadNetwork, from: Vector2, to: Vector2) -> PackedVector2Array:
	if roads == null:
		return PackedVector2Array([from, to])
	var graph := _graph_for(roads)
	if graph.get_point_count() == 0:
		return PackedVector2Array([from, to])
	var start := graph.get_closest_point(roads.to_local(from))
	var finish := graph.get_closest_point(roads.to_local(to))
	var path := PackedVector2Array([from])
	for point in graph.get_point_path(start, finish):
		path.append(roads.to_global(point))
	path.append(to)
	return path

static func _graph_for(roads: RoadNetwork) -> AStar2D:
	if _graph != null and _built_for != null and _built_for.get_ref() == roads:
		return _graph
	_graph = AStar2D.new()
	_built_for = weakref(roads)
	roads.ensure_built()
	var buckets := {}
	var id := 0
	for line in roads.get_road_polylines():
		var previous := -1
		for point in _resample(line):
			_graph.add_point(id, point)
			if previous >= 0:
				_graph.connect_points(previous, id)
			var cell := Vector2i((point / JOIN).floor())
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for other: int in buckets.get(cell + Vector2i(dx, dy), []):
						if other != previous and _graph.get_point_position(other).distance_to(point) <= JOIN:
							_graph.connect_points(other, id)
			var bucket: Array = buckets.get(cell, [])
			bucket.append(id)
			buckets[cell] = bucket
			previous = id
			id += 1
	return _graph

## `line` with a point at least every STEP px along it.
static func _resample(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in line.size():
		if i == 0:
			out.append(line[0])
			continue
		var a := line[i - 1]
		var b := line[i]
		var pieces := maxi(1, ceili(a.distance_to(b) / STEP))
		for j in range(1, pieces + 1):
			out.append(a.lerp(b, float(j) / pieces))
	return out
