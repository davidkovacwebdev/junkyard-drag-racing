class_name HectorBell
extends Node2D
## The brass hand bell on Hector's wheelchair. Whenever the chair rolls he
## rings it nonstop, impatiently; `ring()` lets a cutscene ding it on cue.

const MOVING_SPEED := 20.0
const RING_INTERVAL_MIN := 0.18
const RING_INTERVAL_MAX := 0.45
const WOBBLE_ANGLE := 0.35
const WOBBLE_DECAY := 9.0
const WOBBLE_FREQUENCY := 38.0
const VOLUME_DB := -8.0

var _last_global_position: Vector2
var _time_until_ring := 0.0
var _wobble_time := INF

func _ready() -> void:
	_last_global_position = global_position

func _process(delta: float) -> void:
	var speed := global_position.distance_to(_last_global_position) / maxf(delta, 0.0001)
	_last_global_position = global_position
	_time_until_ring -= delta
	if speed > MOVING_SPEED and _time_until_ring <= 0.0:
		ring()
	_wobble_time += delta
	rotation = WOBBLE_ANGLE * exp(-WOBBLE_DECAY * _wobble_time) * sin(WOBBLE_FREQUENCY * _wobble_time)

func ring() -> void:
	_time_until_ring = randf_range(RING_INTERVAL_MIN, RING_INTERVAL_MAX)
	_wobble_time = 0.0
	Sfx.play_at(&"hector_bell", global_position, VOLUME_DB)
