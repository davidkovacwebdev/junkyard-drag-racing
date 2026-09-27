class_name SpinningPropeller
extends Node2D
## Spins a propeller's art in place. It idles when the car sits still and
## winds up with however fast the car is moving, so it works the same in a
## race, on the map and in the garage. A translucent `Blur` child fades in as
## it speeds up, like a real prop turning into a disc.

## Spin while idling, in rad/s.
@export var idle_speed: float = 8.0
## Extra spin per px/s the car moves.
@export var speed_per_pixel: float = 0.12
@export var max_speed: float = 40.0
@export var blur_opacity: float = 0.35

var _previous_position: Vector2
var _has_previous_position: bool = false
var _spin_speed: float = 0.0

@onready var _blur: Polygon2D = $Blur

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moving_speed := 0.0
	if _has_previous_position:
		moving_speed = (global_position - _previous_position).length() / delta
	_previous_position = global_position
	_has_previous_position = true
	var target_speed := minf(idle_speed + moving_speed * speed_per_pixel, max_speed)
	_spin_speed = lerpf(_spin_speed, target_speed, clampf(3.0 * delta, 0.0, 1.0))
	rotation = wrapf(rotation + _spin_speed * delta, -PI, PI)
	_blur.color.a = clampf(_spin_speed / max_speed, 0.0, 1.0) * blur_opacity
