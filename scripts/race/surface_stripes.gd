class_name SurfaceStripes
extends Node2D
## Periodic tick marks along a floor/ramp segment's own rolling surface —
## a purely visual motion cue. CameraFollow tracks the car with zero lag
## (same design the regular drag race uses — see camera_follow.gd), which
## on a flat, featureless single-car track leaves the car pinned to the
## exact same screen position forever: nothing else is in frame to read
## relative motion against, so a genuinely accelerating car can look
## completely frozen. These stripes are what let the ground itself read
## as scrolling past underneath it.
##
## point_a/point_b are the surface's own two ends, in this node's local
## space — for a flat floor that's just its two horizontal extremes at
## the top edge; for a sloped wedge (the downhill, the ramp) it's the
## rolling hypotenuse itself. One script handles both since stripes are
## always just perpendicular ticks along whatever line connects them.
##
## `points`, if it has 2 or more entries, overrides point_a/point_b with
## a whole polyline instead of one straight segment — for a curved
## surface (the smoothed launch ramp) whose rolling face is really a fan
## of short straight pieces, not one line. Distance keeps accumulating
## across the whole polyline rather than resetting at each vertex, so
## stripes land at an even interval along the true curve instead of
## clumping at the start of every little segment.

@export var point_a: Vector2 = Vector2.ZERO
@export var point_b: Vector2 = Vector2(800.0, 0.0)
@export var points: PackedVector2Array = PackedVector2Array()
@export var interval: float = 150.0
@export var stripe_length: float = 40.0
@export var stripe_width: float = 8.0
@export var color: Color = Color(0.46, 0.46, 0.5, 1)

func _draw() -> void:
	var path := points if points.size() >= 2 else PackedVector2Array([point_a, point_b])
	var half_len := stripe_width * 0.5
	var half_perp := stripe_length * 0.5
	var carry := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var delta := b - a
		var length := delta.length()
		if length <= 0.0:
			continue
		var dir := delta / length
		var perp := dir.orthogonal()
		var d := carry
		while d < length:
			var center := a + dir * d
			var p1 := center + perp * half_perp - dir * half_len
			var p2 := center + perp * half_perp + dir * half_len
			var p3 := center - perp * half_perp + dir * half_len
			var p4 := center - perp * half_perp - dir * half_len
			draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), color)
			d += interval
		carry = d - length
