@tool
class_name JunkRidge
extends Node2D
## One flat silhouette layer of the ramp jump's scenery: a jagged ridge from
## x = 0 to `width` with tyres and panels poking out of it, filled down to
## `depth`. The first and last ridge points match, so it tiles seamlessly under
## a Parallax2D whose repeat_size.x is `width`.

@export var width := 4000.0
## Ridge top, highest to lowest (smaller y is higher).
@export var peak_y := Vector2(600.0, 800.0)
## Spacing between ridge points. Wide spacing reads as far-off hills.
@export var step := Vector2(120.0, 260.0)
@export var depth := 4000.0
@export var color := Color(0.62, 0.49, 0.35)
@export var junk_color := Color(0.56, 0.44, 0.31)
## Share of ridge points with a tyre or panel sticking out. 0 for plain hills.
@export_range(0.0, 1.0) var junk_chance := 0.4
@export var junk_size := 60.0
@export var ridge_seed := 1

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ridge_seed
	var ridge := PackedVector2Array()
	var x := 0.0
	while x < width:
		ridge.append(Vector2(x, rng.randf_range(peak_y.x, peak_y.y)))
		x += rng.randf_range(step.x, step.y)
	ridge.append(Vector2(width, ridge[0].y))

	for i in ridge.size() - 1:
		if rng.randf() < junk_chance:
			_draw_junk(ridge[i], rng)

	var fill := PackedVector2Array(ridge)
	fill.append(Vector2(width, depth))
	fill.append(Vector2(0.0, depth))
	draw_colored_polygon(fill, color)

## A tyre (octagon) or a slab of panel half-buried in the ridge.
func _draw_junk(at: Vector2, rng: RandomNumberGenerator) -> void:
	var angle := rng.randf_range(-0.6, 0.6)
	if rng.randf() < 0.5:
		var radius := junk_size * rng.randf_range(0.6, 1.0)
		draw_colored_polygon(FlatProps.octagon(at, radius, radius), junk_color)
	else:
		var half := Vector2(junk_size * rng.randf_range(0.8, 1.6), junk_size * rng.randf_range(0.25, 0.45))
		var points := PackedVector2Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(at + (corner * half).rotated(angle))
		draw_colored_polygon(points, junk_color)
