class_name CarHamsterWheel
extends CarWheel
## A hamster wheel as a tire, powered by the hamster instead of the engine's
## steady pull. The hamster runs for a while, gets tired, sits down to pant
## (the wheel then just coasts), and gets back to it. A hard knock scares it
## into a panicked sprint. The engine only sets how fast it can run.
##
## The hamster is drawn inside the wheel and always kept upright at the
## bottom, leaning a little up the wheel while it runs.

enum HamsterMood { RUNNING, RESTING, PANICKING }

## Seconds the hamster runs before it needs a rest.
@export var stamina_range: Vector2 = Vector2(2.5, 5.0)
@export var rest_range: Vector2 = Vector2(0.6, 1.6)
@export var panic_time: float = 1.2
## Running speed multiplier while panicking.
@export var panic_speed: float = 1.7
## A velocity change (px/s) this big in one step scares the hamster.
@export var scare_velocity: float = 300.0
## How far from the wheel's centre the hamster's feet touch the rungs.
@export var running_radius: float = 32.0
## How far up the wheel the hamster climbs while running, in radians.
@export var running_climb: float = deg_to_rad(22.0)
## Leg swings per radian the wheel turns.
@export var stride_per_radian: float = 1.4

var _rng := RandomNumberGenerator.new()
var _mood: HamsterMood = HamsterMood.RUNNING
var _mood_time_left: float = 0.0
var _run_effort: float = 1.0
var _previous_velocity := Vector2.ZERO
var _stride_phase: float = 0.0
var _climb: float = 0.0
var _visual_speed: float = 0.0
var _time: float = 0.0

@onready var _hamster: Node2D = $Hamster
@onready var _front_legs: Node2D = $Hamster/FrontLegs
@onready var _back_legs: Node2D = $Hamster/BackLegs
@onready var _hamster_body: Node2D = $Hamster/Body

func _ready() -> void:
	super()
	_rng.randomize()
	_start_running()

func _physics_process(delta: float) -> void:
	if freeze or target_angular_velocity == 0.0:
		return
	var velocity := linear_velocity
	if (velocity - _previous_velocity).length() > scare_velocity and _mood != HamsterMood.PANICKING:
		_mood = HamsterMood.PANICKING
		_mood_time_left = panic_time
		RaceCarAudio.play(self, &"hamster_squeak", global_position, -4.0)
	_previous_velocity = velocity
	_mood_time_left -= delta
	if _mood_time_left > 0.0:
		return
	if _mood == HamsterMood.RESTING:
		_start_running()
	else:
		_mood = HamsterMood.RESTING
		_mood_time_left = _rng.randf_range(rest_range.x, rest_range.y)

func _start_running() -> void:
	_mood = HamsterMood.RUNNING
	_mood_time_left = _rng.randf_range(stamina_range.x, stamina_range.y)
	_run_effort = _rng.randf_range(0.8, 1.15)

func _current_target_speed() -> float:
	match _mood:
		HamsterMood.RESTING:
			return 0.0
		HamsterMood.PANICKING:
			return target_angular_velocity * panic_speed
	return target_angular_velocity * _run_effort

func _process(delta: float) -> void:
	_time += delta
	var spin_speed := _visual_speed if freeze else angular_velocity
	var is_running := absf(spin_speed) > 0.3 and (freeze or _mood != HamsterMood.RESTING)
	_stride_phase += spin_speed * stride_per_radian * delta
	_climb = lerpf(_climb, running_climb * signf(spin_speed) if is_running else 0.0, clampf(4.0 * delta, 0.0, 1.0))
	if absf(spin_speed) > 0.3:
		_hamster.scale.x = signf(spin_speed)
	_pose_hamster(is_running)

## Keeps the hamster upright at the bottom of the wheel, however the wheel
## has turned, with its legs pumping while it runs and its body panting at rest.
func _pose_hamster(is_running: bool) -> void:
	var angle_from_bottom := -rotation - _climb
	_hamster.position = Vector2(0.0, running_radius).rotated(angle_from_bottom)
	_hamster.rotation = angle_from_bottom
	if is_running:
		var swing := sin(_stride_phase * TAU) * 0.7
		_front_legs.rotation = swing
		_back_legs.rotation = -swing
		_hamster_body.position.y = -absf(sin(_stride_phase * TAU)) * 1.5
		_hamster_body.scale = Vector2.ONE
	else:
		_front_legs.rotation = 0.0
		_back_legs.rotation = 0.0
		_hamster_body.position.y = 0.0
		var pant := 1.0 + sin(_time * 14.0) * 0.05
		_hamster_body.scale = Vector2(1.0 / pant, pant)

func animate_visual(distance: float, delta: float) -> void:
	super(distance, delta)
	_visual_speed = distance / visual_roll_radius() / maxf(delta, 0.0001)
