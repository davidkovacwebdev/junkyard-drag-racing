class_name PolygonMorph
extends RefCounted
## Shape blending for the scrap forge: averaging two polygons vertex by vertex,
## and bending a whole drawing toward another drawing's silhouette.

const RING_POINTS := 24
const ENVELOPE_SAMPLES := 128
## How far a silhouette may be stretched or squashed in any one direction. Squash
## is kept mild so the base keeps its own limbs (a horse still has legs) while
## the donor can still grow new ones out of it; the limits also stop a
## sliver of one outline flinging the other part's art off to infinity.
const MAX_STRETCH := 2.6
const MIN_STRETCH := 0.65

## A silhouette seen from `center`: how far out the art reaches at each angle.
## Taking the farthest edge along each ray keeps a horse's legs and neck as
## spikes instead of filling them into a blob the way a convex hull would.
class Envelope:
	var center: Vector2
	var reach: PackedFloat32Array

	func _init(outlines: Array, from: Vector2) -> void:
		center = from
		reach.resize(ENVELOPE_SAMPLES)
		for i in ENVELOPE_SAMPLES:
			var direction := Vector2.from_angle(TAU * i / ENVELOPE_SAMPLES)
			var farthest := 0.0
			for outline: PackedVector2Array in outlines:
				for k in outline.size():
					farthest = maxf(farthest, PolygonMorph.ray_hit(center, direction, outline[k], outline[(k + 1) % outline.size()]))
			reach[i] = farthest
		_fill_gaps()
		_smooth()

	func at(angle: float) -> float:
		var position := fposmod(angle / TAU, 1.0) * ENVELOPE_SAMPLES
		var index := int(position)
		return lerpf(reach[index % ENVELOPE_SAMPLES], reach[(index + 1) % ENVELOPE_SAMPLES], position - index)

	## Rays that hit nothing (the centre sits outside the art on that side)
	## borrow from their nearest neighbours that did hit.
	func _fill_gaps() -> void:
		var biggest := 0.0
		for value in reach:
			biggest = maxf(biggest, value)
		if biggest <= 0.0:
			reach.fill(1.0)
			return
		var filled := reach.duplicate()
		for i in ENVELOPE_SAMPLES:
			if reach[i] > 0.0:
				continue
			for step in range(1, ENVELOPE_SAMPLES / 2):
				var left := reach[(i - step + ENVELOPE_SAMPLES) % ENVELOPE_SAMPLES]
				var right := reach[(i + step) % ENVELOPE_SAMPLES]
				if left > 0.0 or right > 0.0:
					filled[i] = maxf(left, right)
					break
		reach = filled

	func _smooth() -> void:
		var smoothed := reach.duplicate()
		for i in ENVELOPE_SAMPLES:
			var total := 0.0
			for offset in range(-2, 3):
				total += reach[(i + offset + ENVELOPE_SAMPLES) % ENVELOPE_SAMPLES]
			smoothed[i] = total / 5.0
		reach = smoothed

## Moves `point` radially so that where `from` reached, it now reaches `to`.
## Every point is moved by the same rule, so polygons that shared an edge still
## share it afterwards.
static func bend(point: Vector2, from: Envelope, to: Envelope) -> Vector2:
	var offset := point - from.center
	if offset.length_squared() < 0.0001:
		return point
	var angle := offset.angle()
	var stretch := clampf(to.at(angle) / maxf(from.at(angle), 0.001), MIN_STRETCH, MAX_STRETCH)
	return from.center + offset * stretch

## An envelope partway between two others (same centre).
static func blend_envelopes(first: Envelope, second: Envelope, amount: float) -> Envelope:
	var mixed := Envelope.new([], first.center)
	for i in ENVELOPE_SAMPLES:
		mixed.reach[i] = lerpf(first.reach[i], second.reach[i], amount)
	return mixed

## Distance along the ray from `origin` in `direction` to segment a-b, or 0.
static func ray_hit(origin: Vector2, direction: Vector2, a: Vector2, b: Vector2) -> float:
	var edge := b - a
	var denominator := direction.cross(edge)
	if absf(denominator) < 0.000001:
		return 0.0
	var to_a := a - origin
	var along_ray := to_a.cross(edge) / denominator
	var along_edge := to_a.cross(direction) / denominator
	if along_ray > 0.0 and along_edge >= 0.0 and along_edge <= 1.0:
		return along_ray
	return 0.0

## `shape` averaged with `partner`: both are resampled into rings of the same
## size, lined up so each point faces its closest counterpart, and blended
## `amount` of the way. The result keeps `shape`'s place and roughly its size,
## so a horse's leg turned half into a TV knob still swings from the hip.
static func blend(shape: PackedVector2Array, partner: PackedVector2Array, amount: float,
		drift: float) -> PackedVector2Array:
	var shape_center := centroid(shape)
	var partner_center := centroid(partner)
	var ring := _resample(_relative(shape, shape_center), RING_POINTS)
	var other := _resample(_relative(partner, partner_center), RING_POINTS)
	if (PartForge.signed_area(ring) < 0.0) != (PartForge.signed_area(other) < 0.0):
		other.reverse()
	# Turn the partner so its long axis lies along the shape's: a leg paired
	# with a TV scanline becomes a scanline-ish leg, not a leg lying sideways.
	var turn := wrapf(principal_angle(ring) - principal_angle(other), -PI / 2.0, PI / 2.0)
	for i in other.size():
		other[i] = other[i].rotated(turn)
	var size_ratio := sqrt(absf(PartForge.signed_area(shape)) / maxf(absf(PartForge.signed_area(partner)), 0.001))
	for i in other.size():
		other[i] *= size_ratio
	other = _aligned(ring, other)
	var grow := clampf(lerpf(1.0, 1.0 / maxf(size_ratio, 0.001), amount * 0.5), 0.5, 2.0)
	var center := shape_center.lerp(partner_center, drift)
	var mixed := PackedVector2Array()
	for i in ring.size():
		mixed.append(center + ring[i].lerp(other[i], amount) * grow)
	return simplify(mixed, sqrt(absf(PartForge.signed_area(mixed))) * 0.02)

## Direction of the outline's long axis (points taken around their centroid).
static func principal_angle(points: PackedVector2Array) -> float:
	var xx := 0.0
	var yy := 0.0
	var xy := 0.0
	for point in points:
		xx += point.x * point.x
		yy += point.y * point.y
		xy += point.x * point.y
	return 0.5 * atan2(2.0 * xy, xx - yy)

static func centroid(points: PackedVector2Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / maxf(points.size(), 1.0)

## Whether Godot can actually fill this outline (a self-crossing one draws
## nothing at all).
static func is_drawable(points: PackedVector2Array) -> bool:
	return points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty()

## Drops points that sit within `tolerance` of the line through their
## neighbours, so a blend keeps the art's few-corners look.
static func simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() <= 4:
		return points
	var kept := points
	var changed := true
	while changed and kept.size() > 4:
		changed = false
		for i in kept.size():
			var before := kept[(i - 1 + kept.size()) % kept.size()]
			var after := kept[(i + 1) % kept.size()]
			var closest := Geometry2D.get_closest_point_to_segment(kept[i], before, after)
			if kept[i].distance_to(closest) < tolerance:
				kept.remove_at(i)
				changed = true
				break
	return kept

static func _relative(points: PackedVector2Array, center: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(point - center)
	return out

## `count` points spaced evenly along the outline.
static func _resample(points: PackedVector2Array, count: int) -> PackedVector2Array:
	var perimeter := 0.0
	for i in points.size():
		perimeter += points[i].distance_to(points[(i + 1) % points.size()])
	var out := PackedVector2Array()
	if perimeter <= 0.0:
		for i in count:
			out.append(points[0] if not points.is_empty() else Vector2.ZERO)
		return out
	var step := perimeter / count
	var edge := 0
	var edge_start := 0.0
	for i in count:
		var target := i * step
		var edge_length := points[edge].distance_to(points[(edge + 1) % points.size()])
		while edge_start + edge_length < target and edge < points.size() - 1:
			edge_start += edge_length
			edge += 1
			edge_length = points[edge].distance_to(points[(edge + 1) % points.size()])
		var t := (target - edge_start) / maxf(edge_length, 0.0001)
		out.append(points[edge].lerp(points[(edge + 1) % points.size()], clampf(t, 0.0, 1.0)))
	return out

## `other` rotated around its ring so its points best line up with `ring`'s.
static func _aligned(ring: PackedVector2Array, other: PackedVector2Array) -> PackedVector2Array:
	var count := ring.size()
	var best_offset := 0
	var best_cost := INF
	for offset in count:
		var cost := 0.0
		for i in count:
			cost += ring[i].distance_squared_to(other[(i + offset) % count])
			if cost >= best_cost:
				break
		if cost < best_cost:
			best_cost = cost
			best_offset = offset
	var out := PackedVector2Array()
	for i in count:
		out.append(other[(i + best_offset) % count])
	return out
