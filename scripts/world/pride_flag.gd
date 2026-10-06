@tool
class_name PrideFlag
extends StaticBody2D
## A trans pride flag on a pole: light blue, pink, white, pink, light blue,
## flapping in a lazy breeze. Origin at the foot of the pole so it Y-sorts
## against the car. It flies over the Drag Queen's grave in the cemetery.

const POLE := UiPalette.POST_GREY
const POLE_SHADE := Color(0.32, 0.30, 0.27)
const BLUE := Color(0.47, 0.75, 0.9)
const PINK := Color(0.92, 0.66, 0.73)
const WHITE := Color(0.93, 0.92, 0.89)
const STRIPES: Array[Color] = [BLUE, PINK, WHITE, PINK, BLUE]
## Columns across the cloth; the wave bends the stripes at each one.
const WAVE_COLUMNS := 4

@export var pole_height: float = 190.0:
	set(value):
		pole_height = value
		queue_redraw()
@export var flag_size: Vector2 = Vector2(96.0, 64.0):
	set(value):
		flag_size = value
		queue_redraw()
## How far the cloth ripples up and down, and how fast.
@export var wave_pixels: float = 5.0
@export var wave_speed: float = 2.4

var _time: float = 0.0

func _ready() -> void:
	add_to_group(OffscreenCuller.GROUP)
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14.0, 8.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -4.0)
	add_child(collision)
	# Neighbouring flags shouldn't flap in lockstep.
	_time = fmod(global_position.x * 0.013, TAU)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta * wave_speed
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 16.0, 5.0), UiPalette.SHADOW)
	draw_colored_polygon(FlatProps.sliver(Vector2(0.0, 0.0), Vector2(0.0, -pole_height), 7.0), POLE)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -pole_height - 4.0), 7.0, 7.0), POLE_SHADE)
	var top := -pole_height + 6.0
	var stripe_height := flag_size.y / STRIPES.size()
	for i in STRIPES.size():
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for column in WAVE_COLUMNS + 1:
			var t := float(column) / WAVE_COLUMNS
			# Pinned at the pole, flapping more towards the free end.
			var sway := sin(_time - t * 3.0) * wave_pixels * t
			var x := 4.0 + t * flag_size.x
			upper.append(Vector2(x, top + i * stripe_height + sway))
			lower.append(Vector2(x, top + (i + 1) * stripe_height + sway))
		lower.reverse()
		draw_colored_polygon(upper + lower, STRIPES[i])
