@tool
class_name JunkPileBackdrop
extends Control
## One flat layer of the menu's junkyard: an optional sky fill, then a jagged
## junk-pile silhouette along the bottom with tyres and panels poking out of its
## ridge. Stack a far layer and a near layer with the falling parts between them
## and the parts look like they drop into the yard.

@export var sky_color := Color(0.80, 0.68, 0.49)
@export var draw_sky: bool = false
@export var pile_color := Color(0.70, 0.58, 0.42)
@export var junk_color := Color(0.64, 0.52, 0.37)
## Pile ridge height as a fraction of this control's height, low to high.
@export var pile_height := Vector2(0.18, 0.32)
@export var ground_color := Color(0.0, 0.0, 0.0, 0.0)
@export var ground_height: float = 0.0
@export var pile_seed: int = 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if draw_sky:
		draw_rect(Rect2(Vector2.ZERO, size), sky_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = pile_seed

	var ridge := PackedVector2Array()
	var x := -20.0
	while x < size.x + 60.0:
		var height := rng.randf_range(pile_height.x, pile_height.y) * size.y
		ridge.append(Vector2(x, size.y - height))
		x += rng.randf_range(40.0, 95.0)

	for i in ridge.size():
		if rng.randf() < 0.45:
			_draw_junk(ridge[i], rng)

	var pile := PackedVector2Array(ridge)
	pile.append(Vector2(ridge[-1].x, size.y))
	pile.append(Vector2(ridge[0].x, size.y))
	draw_colored_polygon(pile, pile_color)

	if ground_height > 0.0:
		draw_rect(Rect2(0.0, size.y - ground_height, size.x, ground_height), ground_color)

## A tyre (octagon) or a slab of panel half-buried in the ridge.
func _draw_junk(at: Vector2, rng: RandomNumberGenerator) -> void:
	var angle := rng.randf_range(-0.6, 0.6)
	var points := PackedVector2Array()
	if rng.randf() < 0.5:
		var radius := rng.randf_range(16.0, 30.0)
		for k in 8:
			points.append(at + Vector2.from_angle(TAU * k / 8.0 + angle) * radius)
	else:
		var half := Vector2(rng.randf_range(22.0, 48.0), rng.randf_range(7.0, 14.0))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(at + (corner * half).rotated(angle))
	draw_colored_polygon(points, junk_color)
