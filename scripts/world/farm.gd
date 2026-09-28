@tool
class_name Farm
extends Node2D
## The farm landmark: barn, windmill, a fenced paddock with a horse wandering
## about in it, and the farmer who sells horses (see HorseFarmer). Y-sorted, so
## every piece sorts against the car on its own.
##
## The paddock horse is the real engine part, unhitched, walked between random
## spots in `paddock`. Its legs animate off its own movement, exactly as they do
## when it pulls a car.

## Where the paddock horse may roam, in this node's space.
@export var paddock: Rect2 = Rect2(110.0, -70.0, 240.0, 200.0)
@export var horse_walk_speed: float = 70.0
@export var horse_pause_range: Vector2 = Vector2(1.5, 5.0)

var _rng := RandomNumberGenerator.new()
var _horse_target := Vector2.ZERO
var _horse_pause := 0.0

@onready var _horse: HorseEngine = $PaddockHorse

func _ready() -> void:
	# HorseEngine isn't a tool script, so in the editor it's only a placeholder.
	if Engine.is_editor_hint():
		return
	_horse.set_hitched(false)
	_rng.randomize()
	_horse_target = _horse.position
	_horse_pause = _rng.randf_range(horse_pause_range.x, horse_pause_range.y)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _horse.position.distance_to(_horse_target) < 1.0:
		_horse_pause -= delta
		if _horse_pause <= 0.0:
			_horse_target = Vector2(_rng.randf_range(paddock.position.x, paddock.end.x),
					_rng.randf_range(paddock.position.y, paddock.end.y))
			_horse_pause = _rng.randf_range(horse_pause_range.x, horse_pause_range.y)
		return
	var heading := _horse_target - _horse.position
	if absf(heading.x) > 1.0:
		_horse.scale.x = absf(_horse.scale.x) * signf(heading.x)
	_horse.position = _horse.position.move_toward(_horse_target, horse_walk_speed * delta)
