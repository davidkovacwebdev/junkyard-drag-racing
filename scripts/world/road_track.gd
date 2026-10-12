class_name RoadTrack
extends RefCounted
## A road polyline with the arc length at each of its points, so sampling
## and closest-point lookups binary-search to the right segment instead of
## walking from the road's start. Built by RoadGraph, which also fills in
## `stops`: every junction along the road.

var points: PackedVector2Array
var distances := PackedFloat32Array()
var length := 0.0
## {station: float, junction: RoadGraph.Junction}, sorted by station (arc
## length along this road).
var stops: Array[Dictionary] = []

func _init(road_points: PackedVector2Array) -> void:
	points = road_points
	distances.resize(points.size())
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
		distances[i] = length

func first_point() -> Vector2:
	return points[0]

func last_point() -> Vector2:
	return points[points.size() - 1]

## Which way the road runs from arc length `from` to `to`.
func heading(from: float, to: float) -> Vector2:
	return sample(from).direction_to(sample(to))

## The first junction strictly past `station` going the given way, or {} if
## the road just runs out.
func stop_after(station: float, forward: bool) -> Dictionary:
	if forward:
		for stop in stops:
			if stop["station"] > station + 1.0:
				return stop
	else:
		for i in range(stops.size() - 1, -1, -1):
			if stops[i]["station"] < station - 1.0:
				return stops[i]
	return {}

## Point `distance` along the road, clamped to its ends.
func sample(distance: float) -> Vector2:
	if distance <= 0.0:
		return points[0]
	if distance >= length:
		return last_point()
	var i := _segment_at(distance)
	var segment := distances[i + 1] - distances[i]
	if segment <= 0.0:
		return points[i]
	return points[i].lerp(points[i + 1], (distance - distances[i]) / segment)

## Arc length of the point closest to `position`, only looking within
## `window` of `around` so a road that doubles back past itself can't make
## the truck's progress jump to the wrong stretch.
func closest_travelled(position: Vector2, around: float, window: float) -> float:
	var best_distance := INF
	var best_travelled := around
	var first := _segment_at(around - window)
	var last := _segment_at(around + window)
	for i in range(first, last + 1):
		var a := points[i]
		var b := points[i + 1]
		var segment := distances[i + 1] - distances[i]
		if segment <= 0.0:
			continue
		var t := clampf((position - a).dot(b - a) / (segment * segment), 0.0, 1.0)
		var distance := position.distance_squared_to(a.lerp(b, t))
		if distance < best_distance:
			best_distance = distance
			best_travelled = distances[i] + t * segment
	return best_travelled

## Index of the segment containing arc length `distance`, clamped.
func _segment_at(distance: float) -> int:
	return clampi(distances.bsearch(distance, true) - 1, 0, points.size() - 2)
