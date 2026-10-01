class_name RocketExhaustAccessory
extends CarAccessory
## A rocket nozzle out the back with a flame that grows with speed and
## flickers.

@export var idle_length: float = 0.45
@export var full_speed_length: float = 1.4
@export var flicker_amount: float = 0.15
@export var flicker_rate: float = 31.0

@onready var _flame: Node2D = $Flame

var _time: float = 0.0

func _process(delta: float) -> void:
	super(delta)
	_time += delta
	var length := lerpf(idle_length, full_speed_length, speed_fraction())
	var flicker := 1.0 + flicker_amount * sin(_time * flicker_rate) * sin(_time * flicker_rate * 0.37)
	_flame.scale = Vector2(length * flicker, 1.0 + (flicker - 1.0) * 0.5)
