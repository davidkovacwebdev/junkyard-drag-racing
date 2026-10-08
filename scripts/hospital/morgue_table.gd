class_name MorgueTable
extends Node2D
## The steel slab in the hospital morgue, with Grandpa on it under a sheet:
## after the crane, he's so flat the sheet lies dead level, a line on the
## table, with only his red cowboy boots poking out the end (the gag).
## Origin on the floor under the middle of the slab, so it Y-sorts against
## the people standing round it.

const STEEL := Color(0.66, 0.68, 0.7, 1)
const STEEL_SHADE := Color(0.5, 0.52, 0.55, 1)
const SHEET := Color(0.86, 0.9, 0.92, 1)
## Grandpa's boots (boots_cowboy_red), squashed as flat as the rest of him.
const BOOT := Color(0.6, 0.16, 0.13, 1)

@export var length: float = 300.0
@export var height: float = 92.0

func _draw() -> void:
	var half := length * 0.5
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, half + 10.0, 14.0), UiPalette.SHADOW)
	# Two chunky legs, the slab, and its front edge in shade.
	draw_rect(Rect2(-half + 26.0, -height, 16.0, height), STEEL_SHADE)
	draw_rect(Rect2(half - 42.0, -height, 16.0, height), STEEL_SHADE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half, -height - 26.0), Vector2(half, -height - 28.0),
		Vector2(half + 4.0, -height), Vector2(-half - 2.0, -height + 2.0),
	]), STEEL)
	draw_rect(Rect2(-half - 2.0, -height, length + 6.0, 10.0), STEEL_SHADE)
	# The sheet: one flat line, end to end.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half + 20.0, -height - 22.0), Vector2(half - 54.0, -height - 23.0),
		Vector2(half - 52.0, -height - 14.0), Vector2(-half + 18.0, -height - 13.0),
	]), SHEET)
	# His boots, out the end of it.
	draw_colored_polygon(PackedVector2Array([
		Vector2(half - 54.0, -height - 22.0), Vector2(half - 14.0, -height - 30.0),
		Vector2(half - 10.0, -height - 22.0), Vector2(half - 52.0, -height - 14.0),
	]), BOOT)
