class_name EffectBadge
extends Control
## A little star tag on a part card that says "this part does something
## special". The card itself carries the tooltip saying what.

const STAR_POINTS := 5
const TILT := deg_to_rad(-6.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(26, 26)

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_colored_polygon(_tag(center + Vector2(1.5, 2.0), radius), UiPalette.SHADOW)
	draw_colored_polygon(_tag(center, radius), UiPalette.SURFACE_DARK)
	draw_colored_polygon(_star(center, radius * 0.78, radius * 0.38), UiPalette.ACCENT_YELLOW)

static func _tag(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 8:
		points.append(center + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0 + TILT) * radius)
	return points

static func _star(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in STAR_POINTS * 2:
		var point_radius := outer_radius if k % 2 == 0 else inner_radius
		points.append(center + Vector2.from_angle(TAU * k / (STAR_POINTS * 2) - PI / 2.0 + TILT) * point_radius)
	return points
