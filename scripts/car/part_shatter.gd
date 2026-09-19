class_name PartShatter
extends RefCounted
## Physics-driven "it broke" effect: spawns a handful of small debris
## RigidBody2D chunks at the part's position, carrying its own momentum
## plus an outward scatter impulse, then removes the original part.
## Fragments are generic rubble (not a polygon-accurate split of the
## original shape) — simple and shape-agnostic, which matters here since
## parts can be anything from a plank to a toilet bowl.

const FRAGMENT_COUNT := 6
const FRAGMENT_SPEED_MIN := 100.0
const FRAGMENT_SPEED_MAX := 260.0

static func shatter(part: RigidBody2D, color: Color, parent: Node) -> void:
	var origin := part.global_position
	var base_velocity := part.linear_velocity
	var base_mass := maxf(part.mass, 1.0)

	for i in FRAGMENT_COUNT:
		var frag := RigidBody2D.new()
		frag.mass = maxf(base_mass / FRAGMENT_COUNT, 0.3)

		var size := randf_range(6.0, 16.0)
		var poly := PackedVector2Array([
			Vector2(-size, -size), Vector2(size, -size),
			Vector2(size, size), Vector2(-size, size),
		])

		var visual := Polygon2D.new()
		visual.polygon = poly
		visual.color = color
		frag.add_child(visual)

		var collision := CollisionPolygon2D.new()
		collision.polygon = poly
		frag.add_child(collision)

		parent.add_child(frag)
		frag.global_position = origin + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))

		var outward := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if outward.length() < 0.01:
			outward = Vector2.RIGHT
		outward = outward.normalized() * randf_range(FRAGMENT_SPEED_MIN, FRAGMENT_SPEED_MAX)
		frag.linear_velocity = base_velocity + outward
		frag.angular_velocity = randf_range(-12.0, 12.0)

	part.queue_free()
