class_name SirenAccessory
extends CarAccessory
## A police light bar on the roof flashing red and blue, one side at a time.
## The horn becomes a siren while it's fitted (AccessoryPartData.horn_sound).

@export var flash_rate: float = 3.0
@export var dim_amount: float = 0.45

@onready var _left: Polygon2D = $LeftLight
@onready var _right: Polygon2D = $RightLight

var _left_color: Color
var _right_color: Color
var _time: float = 0.0

func _ready() -> void:
	super()
	_left_color = _left.color
	_right_color = _right.color

func _process(delta: float) -> void:
	super(delta)
	_time += delta
	var left_on := fmod(_time * flash_rate, 1.0) < 0.5
	_left.color = _left_color if left_on else _left_color.darkened(dim_amount)
	_right.color = _right_color.darkened(dim_amount) if left_on else _right_color
