class_name GpsArrowAccessory
extends CarAccessory
## A big floating waypoint arrow, like every driving mission ever: on the map it
## points at wherever the tracked quest sends you. With nowhere to go (or in the
## garage) it slowly spins, recalculating. Drive away from the target for a bit
## and it bloops at you.

@export var bob_height: float = 4.0
@export var bob_rate: float = 3.0
@export var idle_spin_rate: float = 1.4
@export var turn_rate: float = 6.0

const TARGET_LOOKUP_INTERVAL := 0.25
const WRONG_WAY_DOT := -0.5
const WRONG_WAY_TIME := 1.5
const RECALCULATE_COOLDOWN := 8.0
const MIN_MOVING_SPEED := 40.0

@onready var _pointer: Node2D = $Pointer

var _pointer_rest_y: float = 0.0
var _time: float = 0.0
var _target := Vector2.INF
var _lookup_timer: float = 0.0
var _wrong_way_time: float = 0.0
var _recalculate_cooldown: float = 0.0

func _ready() -> void:
	super()
	_pointer_rest_y = _pointer.position.y

func _process(delta: float) -> void:
	super(delta)
	_time += delta
	_pointer.position.y = _pointer_rest_y + sin(_time * bob_rate) * bob_height
	_update_target(delta)
	if _target == Vector2.INF:
		_pointer.rotation = wrapf(_pointer.rotation + idle_spin_rate * delta, -PI, PI)
		return
	var to_target := _target - _pointer.global_position
	var local_direction := global_transform.affine_inverse().basis_xform(to_target)
	_pointer.rotation = lerp_angle(_pointer.rotation, local_direction.angle(), clampf(turn_rate * delta, 0.0, 1.0))
	_check_wrong_way(to_target, delta)

## Only the map car has somewhere to go: the garage and races just spin.
func _update_target(delta: float) -> void:
	if not audible or in_race:
		_target = Vector2.INF
		return
	_lookup_timer -= delta
	if _lookup_timer <= 0.0:
		_lookup_timer = TARGET_LOOKUP_INTERVAL
		_target = Quests.tracked_target_position()

func _check_wrong_way(to_target: Vector2, delta: float) -> void:
	_recalculate_cooldown -= delta
	var heading_away := moving_velocity.length() > MIN_MOVING_SPEED \
			and moving_velocity.normalized().dot(to_target.normalized()) < WRONG_WAY_DOT
	_wrong_way_time = _wrong_way_time + delta if heading_away else 0.0
	if _wrong_way_time >= WRONG_WAY_TIME and _recalculate_cooldown <= 0.0:
		_recalculate_cooldown = RECALCULATE_COOLDOWN
		_wrong_way_time = 0.0
		play_sound(&"gps_bloop", -8.0)
