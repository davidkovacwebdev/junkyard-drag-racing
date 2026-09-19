class_name Road
extends Node2D
## Decorative road on the world map: asphalt with shoulders and a dashed
## center line, drawn as a flat overhead strip. Purely cosmetic — there's
## no collision, the player just drives over it on the way between places.

@export var length: float = 1340.0
@export var width: float = 100.0
@export var asphalt_color: Color = Color(0.32, 0.32, 0.35, 1)
@export var shoulder_color: Color = Color(0.24, 0.24, 0.26, 1)
@export var line_color: Color = Color(1, 1, 0.25, 0.7)
@export var dash_length: float = 60.0
@export var dash_gap: float = 50.0

func _draw() -> void:
	var half_len := length / 2.0
	var half_w := width / 2.0
	# Shoulders then asphalt, so the road reads as raised off the sand.
	draw_rect(Rect2(-half_len - 10.0, -half_w - 10.0, length + 20.0, width + 20.0), shoulder_color)
	draw_rect(Rect2(-half_len, -half_w, length, width), asphalt_color)
	# Dashed center line.
	var x := -half_len + dash_gap
	while x < half_len:
		var seg := minf(dash_length, half_len - x)
		draw_line(Vector2(x, 0), Vector2(x + seg, 0), line_color, 4.0)
		x += dash_length + dash_gap
