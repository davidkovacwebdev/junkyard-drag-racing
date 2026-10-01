class_name SwingAccessory
extends CarAccessory
## Something hanging off the car on a string or chain (tin cans, an anchor, a
## balloon): its `Swing` node trails behind as the car moves, wobbles, and can
## bob. Things hanging down use a positive `trail_angle`, things floating up
## (the balloon) a negative one, so both trail backwards.

@export var trail_angle: float = 0.6
@export var wobble_angle: float = 0.08
@export var wobble_rate: float = 5.0
@export var bob_height: float = 0.0
@export var bob_rate: float = 2.0
## Looping sound whose level follows the car's speed (the cans rattling).
@export var rattle_sound: StringName = &""
@export var rattle_volume_db: float = -14.0

@onready var _swing: Node2D = $Swing

var _time: float = 0.0
var _swing_rest_y: float = 0.0
var _rattle: SustainedSound

func _ready() -> void:
	super()
	_swing_rest_y = _swing.position.y
	_time = randf() * TAU
	if audible and rattle_sound != &"":
		_rattle = SustainedSound.new()
		_rattle.sound_name = rattle_sound
		_rattle.base_volume_db = rattle_volume_db + (RaceCarAudio.mix_db(self) if in_race else 0.0)
		add_child(_rattle)

func _process(delta: float) -> void:
	super(delta)
	_time += delta
	var speed := speed_fraction()
	var wobble := sin(_time * wobble_rate) * wobble_angle * (0.4 + speed)
	_swing.rotation = lerp_angle(_swing.rotation, forward_fraction() * trail_angle + wobble, clampf(6.0 * delta, 0.0, 1.0))
	_swing.position.y = _swing_rest_y + sin(_time * bob_rate) * bob_height
	if _rattle != null:
		_rattle.set_level(speed)
