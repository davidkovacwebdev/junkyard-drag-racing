class_name WindupKeyAccessory
extends CarAccessory
## A giant toy wind-up key in the back of the car. The bow turns around the
## stem (seen side-on, it narrows and widens), slowly when parked and faster
## the faster the car goes.

@export var idle_turn_rate: float = 1.5
@export var full_speed_turn_rate: float = 12.0

@onready var _bow: Node2D = $Key/Bow

var _turn: float = 0.0

func _process(delta: float) -> void:
	super(delta)
	_turn += lerpf(idle_turn_rate, full_speed_turn_rate, speed_fraction()) * delta
	_bow.scale.y = cos(_turn)
