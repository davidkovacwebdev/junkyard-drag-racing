@tool
class_name WildflowerPatch
extends Node2D
## A flat patch of meadow flowers lying on the grass: one darker grass blob and
## a handful of chunky flower dots on it, seeded from `pattern_seed` so each patch is
## laid out differently. Ground decor only, no collision, so it lives below the
## Y-sorted props.

const GRASS := Color(0.49, 0.62, 0.33)
const PETALS: Array[Color] = [Color(0.86, 0.45, 0.58), Color(0.93, 0.78, 0.3), Color(0.92, 0.9, 0.84), Color(0.85, 0.5, 0.25)]
const FLOWER_COUNT := 6

@export var radius: Vector2 = Vector2(260.0, 120.0):
	set(value):
		radius = value
		queue_redraw()
@export var pattern_seed: int = 1:
	set(value):
		pattern_seed = value
		queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = pattern_seed
	draw_colored_polygon(PackedVector2Array([
		Vector2(-radius.x, 0.0), Vector2(-radius.x * 0.6, -radius.y * 0.9), Vector2(radius.x * 0.2, -radius.y),
		Vector2(radius.x * 0.9, -radius.y * 0.5), Vector2(radius.x, radius.y * 0.3), Vector2(radius.x * 0.4, radius.y),
		Vector2(-radius.x * 0.5, radius.y * 0.85),
	]), GRASS)
	for i in FLOWER_COUNT:
		var spot := Vector2(rng.randf_range(-0.75, 0.75) * radius.x, rng.randf_range(-0.6, 0.6) * radius.y)
		var size := rng.randf_range(24.0, 34.0)
		draw_colored_polygon(FlatProps.octagon(spot, size, size * 0.7), PETALS[i % PETALS.size()])
