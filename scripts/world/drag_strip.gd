class_name DragStrip
extends Node2D
## Decorative overhead view of the drag strip on the world map: a long
## asphalt strip with a two-lane divider, a start line and a checkered
## finish line, plus grandstands by the finish. The point is that the
## place is recognisable as a drag strip from the map alone, before the
## player drives up to the entrance booth.

@export var length: float = 2800.0
@export var width: float = 360.0
## Local x of the staging/start line and the checkered finish line.
@export var start_x: float = -1150.0
@export var finish_x: float = 1200.0
@export var asphalt_color: Color = Color(0.45, 0.45, 0.48, 1)
@export var shoulder_color: Color = Color(0.56, 0.52, 0.46, 1)
@export var edge_color: Color = Color(1, 1, 1, 0.85)
@export var divider_color: Color = Color(1, 1, 0.2, 0.6)
@export var burnout_color: Color = Color(0.34, 0.34, 0.37, 1)
@export var stand_color: Color = Color(0.55, 0.5, 0.44, 1)
## Number of checker rows across the strip's width (columns is always 2).
@export var checker_rows: int = 16

func _draw() -> void:
	var half_len := length / 2.0
	var half_w := width / 2.0

	# Grandstands flanking the finish straight.
	draw_rect(Rect2(finish_x - 620.0, -half_w - 130.0, 1000.0, 90.0), stand_color)
	draw_rect(Rect2(finish_x - 620.0, half_w + 40.0, 1000.0, 90.0), stand_color)

	# Shoulders then asphalt.
	draw_rect(Rect2(-half_len - 18.0, -half_w - 18.0, length + 36.0, width + 36.0), shoulder_color)
	draw_rect(Rect2(-half_len, -half_w, length, width), asphalt_color)

	# Edge lines down both sidewalls.
	draw_line(Vector2(-half_len, -half_w + 4.0), Vector2(half_len, -half_w + 4.0), edge_color, 4.0)
	draw_line(Vector2(-half_len, half_w - 4.0), Vector2(half_len, half_w - 4.0), edge_color, 4.0)

	# Dashed center divider between the two lanes.
	var x := -half_len + 40.0
	while x < half_len:
		var seg := minf(70.0, half_len - x)
		draw_line(Vector2(x, 0), Vector2(x + seg, 0), divider_color, 5.0)
		x += 120.0

	# Darker burnout box just before the start line.
	draw_rect(Rect2(start_x - 260.0, -half_w, 260.0, width), burnout_color)

	# Start line.
	draw_rect(Rect2(start_x - 6.0, -half_w, 12.0, width), Color(1, 1, 1, 0.95))

	# Checkered finish line, centred on finish_x.
	var rows := maxi(checker_rows, 1)
	var cell := width / float(rows)
	var cols := 2
	var band_left := finish_x - (cols * cell) / 2.0
	for r in rows:
		for c in cols:
			var white := (r + c) % 2 == 0
			var color := Color(1, 1, 1, 1) if white else Color(0.05, 0.05, 0.05, 1)
			draw_rect(Rect2(band_left + c * cell, -half_w + r * cell, cell, cell), color)
