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

@export var point_a: Vector2 = Vector2.ZERO
@export var point_b: Vector2 = Vector2(800.0, 0.0)
@export var interval: float = 150.0
@export var stripe_length: float = 40.0
@export var stripe_width: float = 8.0
@export var color: Color = Color(0.46, 0.46, 0.5, 1)

func _draw() -> void:
	var delta := point_b - point_a
	var length := delta.length()
	if length <= 0.0:
		return
	var dir := delta / length
	var perp := dir.orthogonal()
	var half_len := stripe_width * 0.5
	var half_perp := stripe_length * 0.5
	var d := 0.0
	while d < length:
		var center := point_a + dir * d
		var p1 := center + perp * half_perp - dir * half_len
		var p2 := center + perp * half_perp + dir * half_len
		var p3 := center - perp * half_perp + dir * half_len
		var p4 := center - perp * half_perp - dir * half_len
		draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), color)
		d += interval
