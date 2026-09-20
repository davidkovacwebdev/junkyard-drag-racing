class_name RoundedRectShape
extends RefCounted
## Godot has no built-in "rounded rectangle" collision primitive, so this
## builds one as a convex polygon: a quarter-circle arc at each corner
## instead of a sharp 90° point.
##
## Why this matters for a CharacterBody2D driven with move_and_slide(): the
## slide direction it picks comes from the collision normal at the point of
## contact. At a real corner that normal is undefined/discontinuous, which is
## what makes the car catch and stop dead when it clips one head-on. Along a
## curve the normal always points smoothly outward, so the car deflects and
## slides around it instead.

const SEGMENTS_PER_CORNER := 6

## `radius` is clamped to at most half the shorter side, so the four corner
## arcs can never overlap into a self-intersecting shape.
static func build(size: Vector2, radius: float) -> ConvexPolygonShape2D:
	var r: float = clampf(radius, 0.0, minf(size.x, size.y) * 0.5)
	var half := size / 2.0
	var points := PackedVector2Array()
	if r < 0.01:
		points.append(Vector2(-half.x, -half.y))
		points.append(Vector2(half.x, -half.y))
		points.append(Vector2(half.x, half.y))
		points.append(Vector2(-half.x, half.y))
	else:
		# One arc per corner, wound consistently clockwise so together they
		# trace the whole rounded rectangle as a single closed loop.
		var corners := [
			[Vector2(half.x - r, -half.y + r), -PI / 2.0], # top-right
			[Vector2(half.x - r, half.y - r), 0.0],         # bottom-right
			[Vector2(-half.x + r, half.y - r), PI / 2.0],   # bottom-left
			[Vector2(-half.x + r, -half.y + r), PI],        # top-left
		]
		for corner in corners:
			var center: Vector2 = corner[0]
			var start_angle: float = corner[1]
			for i in SEGMENTS_PER_CORNER + 1:
				var angle := start_angle + (float(i) / SEGMENTS_PER_CORNER) * (PI / 2.0)
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
	var shape := ConvexPolygonShape2D.new()
	shape.points = points
	return shape
