@tool
class_name CropField
extends Node2D
## A farm field: flat ground with a few chunky crop rows across it. Drivable,
## so no collision. The origin is the top-left corner and it draws only below
## and right of it, so it stays under everything it Y-sorts with (like
## FarmProp's yard).

enum Crop { PLOWED, WHEAT, CABBAGE }

@export var crop: Crop = Crop.WHEAT:
	set(value):
		crop = value
		queue_redraw()
@export var field_size: Vector2 = Vector2(420, 260):
	set(value):
		field_size = value
		queue_redraw()

const WHEAT := Color(0.74, 0.6, 0.28)
const CABBAGE := Color(0.42, 0.56, 0.3)

const ROW_SPACING := 52.0
const MAX_ROWS := 8
const CABBAGE_BUMP := 48.0

func _draw() -> void:
	var w := field_size.x
	var h := field_size.y
	var ground := WHEAT if crop == Crop.WHEAT else FarmProp.DIRT
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 6.0), Vector2(w - 6.0, h), Vector2(4.0, h - 4.0)]), ground)
	var rows := clampi(int(h / ROW_SPACING), 1, MAX_ROWS)
	var gap := h / rows
	for i in rows:
		var y := gap * (i + 0.5)
		match crop:
			Crop.PLOWED:
				draw_rect(Rect2(10.0, y - 6.0, w - 22.0, 12.0), FarmProp.DIRT_DARK)
			Crop.WHEAT:
				draw_rect(Rect2(10.0, y - 10.0, w - 22.0, 20.0), FarmProp.STRAW_LIGHT)
			Crop.CABBAGE:
				draw_colored_polygon(_cabbage_row(y, w), CABBAGE)

## One row of cabbages as a single bumpy band: a flat bottom with a chunky
## bump on top for each head.
func _cabbage_row(y: float, w: float) -> PackedVector2Array:
	var heads := maxi(1, int((w - 24.0) / CABBAGE_BUMP))
	var step := (w - 24.0) / heads
	var points := PackedVector2Array([Vector2(12.0, y + 10.0)])
	for i in heads:
		var left := 12.0 + step * i
		points.append(Vector2(left + 4.0, y - 4.0))
		points.append(Vector2(left + step * 0.3, y - 14.0))
		points.append(Vector2(left + step * 0.7, y - 14.0))
		points.append(Vector2(left + step - 4.0, y - 4.0))
	points.append(Vector2(w - 12.0, y + 10.0))
	return points
