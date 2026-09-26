@tool
class_name WorkshopBackdrop
extends Control
## The garage's back wall and floor, in flat tone steps: dark plank wall with
## seams, a concrete floor with a shade band where it meets the wall.

const WALL := Color(0.36, 0.26, 0.17)
const WALL_SEAM := Color(0.31, 0.22, 0.14)
const FLOOR := Color(0.40, 0.38, 0.34)
const FLOOR_SHADE := Color(0.34, 0.32, 0.29)
const OIL_STAIN := Color(0.30, 0.28, 0.26)

@export var floor_height: float = 150.0:
	set(value):
		floor_height = value
		queue_redraw()
@export var plank_width := Vector2(60.0, 95.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var floor_top := size.y - floor_height
	draw_rect(Rect2(0.0, 0.0, size.x, floor_top), WALL)
	var x := rng.randf_range(0.0, plank_width.x)
	while x < size.x:
		var lean := rng.randf_range(-3.0, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + 4.0, 0.0),
				Vector2(x + 4.0 + lean, floor_top), Vector2(x + lean, floor_top)]), WALL_SEAM)
		x += rng.randf_range(plank_width.x, plank_width.y)
	draw_rect(Rect2(0.0, floor_top, size.x, floor_height), FLOOR)
	draw_rect(Rect2(0.0, floor_top, size.x, 14.0), FLOOR_SHADE)
	for i in 3:
		var centre := Vector2(rng.randf_range(40.0, size.x - 40.0), rng.randf_range(floor_top + 40.0, size.y - 20.0))
		var stain := PackedVector2Array()
		for k in 8:
			stain.append(centre + Vector2.from_angle(TAU * k / 8.0) * Vector2(rng.randf_range(30.0, 60.0), rng.randf_range(8.0, 14.0)))
		draw_colored_polygon(stain, OIL_STAIN)
