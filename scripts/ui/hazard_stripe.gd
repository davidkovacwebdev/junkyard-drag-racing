@tool
class_name HazardStripe
extends Control
## Divider strip of alternating yellow / ink parallelograms.

@export var stripe_width: float = 18.0:
	set(value):
		stripe_width = value
		queue_redraw()
@export var slant: float = 8.0:
	set(value):
		slant = value
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.ACCENT_YELLOW)
	var x := -slant
	while x < size.x:
		var half := stripe_width * 0.5
		var points := PackedVector2Array([
			Vector2(x + slant, 0.0), Vector2(x + slant + half, 0.0),
			Vector2(x + half, size.y), Vector2(x, size.y)])
		# Clamp to the strip; the ends come out slightly squashed, which suits.
		for i in points.size():
			points[i].x = clampf(points[i].x, 0.0, size.x)
		if points[1].x - points[0].x > 0.5 or points[2].x - points[3].x > 0.5:
			draw_colored_polygon(points, UiPalette.INK)
		x += stripe_width
