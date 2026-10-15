class_name CarEngineDrive
extends Node
## How a race car's engine delivers its power over time, per its
## EnginePartData.drive_pattern: a V6 climbing through its gears, a jet
## spooling up, a firework kicking hard then fizzling, a sail at the mercy of
## the wind. Every physics step it sets each wheel's drive_scale (share of top
## spin to head for) and drive_torque_scale (low gears pull harder).

## Shared with CarAssembler, which drops a wheel from it when the wheel breaks.
var wheels: Array[CarWheel] = []
var engine: EnginePartData
var body: CarBody

## GEARED: share of top spin each gear reaches is (gear / gear_count) to this
## power, so the low gears are a bit taller than an even split.
const GEAR_SPREAD := 0.75
## GEARED: shifts up once the wheels reach this share of the gear's top spin...
const UPSHIFT_AT := 0.9
## ...and back down when they fall under this share of the gear below's.
const DOWNSHIFT_AT := 0.5
const MIN_SECONDS_IN_GEAR := 0.3
## SPOOL: share of full drive at the very start.
const SPOOL_IDLE := 0.12
## BURST: share of full drive at the kick, and what's left once it's spent.
const BURST_PEAK := 1.5
const BURST_SPENT := 0.3
## GUSTY: the wind wanders between these shares of full drive.
const GUST_RANGE := Vector2(0.15, 1.25)
## PULSE: how far each stroke surges above and sags below full drive.
const PULSE_DEPTH := 0.45
## SPUTTER: share of drive left mid-cough, and how long a cough lasts.
const COUGH_DRIVE := 0.4
const COUGH_SECONDS := 0.3

var _elapsed := 0.0
var _gear := 1
var _seconds_in_gear := 0.0
var _gust_noise := FastNoiseLite.new()
var _next_cough := 0.0
var _cough_left := 0.0

func _ready() -> void:
	_gust_noise.seed = randi()
	_gust_noise.frequency = 1.0
	if engine != null:
		_next_cough = engine.drive_time * randf_range(0.5, 1.5)

func _physics_process(delta: float) -> void:
	if engine == null:
		return
	_elapsed += delta
	var scale := 1.0
	var torque_scale := 1.0
	match engine.drive_pattern:
		EnginePartData.DrivePattern.GEARED:
			_update_gear(delta)
			scale = gear_ratio(_gear)
			torque_scale = 1.0 / scale
		EnginePartData.DrivePattern.SPOOL:
			scale = lerpf(SPOOL_IDLE, 1.0, 1.0 - exp(-_elapsed / maxf(engine.drive_time, 0.01)))
		EnginePartData.DrivePattern.BURST:
			scale = lerpf(BURST_SPENT, BURST_PEAK, exp(-_elapsed / maxf(engine.drive_time, 0.01)))
			torque_scale = scale
		EnginePartData.DrivePattern.GUSTY:
			var gust := _gust_noise.get_noise_1d(_elapsed / maxf(engine.drive_time, 0.01) * 0.5) * 0.5 + 0.5
			scale = lerpf(GUST_RANGE.x, GUST_RANGE.y, gust)
			torque_scale = scale
		EnginePartData.DrivePattern.PULSE:
			scale = 1.0 + PULSE_DEPTH * sin(TAU * _elapsed / maxf(engine.drive_time, 0.01))
			torque_scale = scale
		EnginePartData.DrivePattern.SPUTTER:
			scale = _sputter(delta)
			torque_scale = scale
	for wheel in wheels:
		if is_instance_valid(wheel):
			wheel.drive_scale = scale
			wheel.drive_torque_scale = torque_scale

## Share of top spin `gear` reaches.
func gear_ratio(gear: int) -> float:
	return pow(float(gear) / maxi(engine.gear_count, 1), GEAR_SPREAD)

## The spin the engine sound treats as the top of its rev range for `wheel`:
## a geared engine revs up to the top of each gear, the rest to their full spin.
func rev_target(wheel: CarWheel) -> float:
	if engine != null and engine.drive_pattern == EnginePartData.DrivePattern.GEARED:
		return wheel.driven_target()
	return wheel.target_angular_velocity

func _update_gear(delta: float) -> void:
	_seconds_in_gear += delta
	if _seconds_in_gear < MIN_SECONDS_IN_GEAR:
		return
	var spin_fraction := _average_spin_fraction()
	if _gear < engine.gear_count and spin_fraction >= gear_ratio(_gear) * UPSHIFT_AT:
		_shift(_gear + 1)
	elif _gear > 1 and spin_fraction < gear_ratio(_gear - 1) * DOWNSHIFT_AT:
		_shift(_gear - 1)

func _shift(gear: int) -> void:
	_gear = gear
	_seconds_in_gear = 0.0
	if is_instance_valid(body):
		RaceCarAudio.play(body, &"gear_shift", body.global_position, -10.0)

## How fast the wheels spin as a share of their full top spin.
func _average_spin_fraction() -> float:
	var total := 0.0
	var count := 0
	for wheel in wheels:
		if is_instance_valid(wheel) and wheel.target_angular_velocity != 0.0:
			total += absf(wheel.angular_velocity / wheel.target_angular_velocity)
			count += 1
	return total / count if count > 0 else 0.0

func _sputter(delta: float) -> float:
	if _cough_left > 0.0:
		_cough_left -= delta
		return COUGH_DRIVE
	_next_cough -= delta
	if _next_cough <= 0.0:
		_next_cough = engine.drive_time * randf_range(0.5, 1.5)
		_cough_left = COUGH_SECONDS
		if is_instance_valid(body):
			RaceCarAudio.play(body, &"engine_cough", body.global_position, -8.0)
		return COUGH_DRIVE
	return 1.0
