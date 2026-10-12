class_name RampJump
extends Node2D
## One run off the overworld ramp (RampEvent) by the map car. The car keeps
## its speed and lane while this works out how high off the ground it is: up
## the launch deck, off the lip, through the air, then down onto the landing
## ramp or the dirt past it, bouncing if it comes down hard. Fast enough (a
## Shift sprint) and it backflips, and landing wheels-up is a crash.
##
## A child of the PlayerCar, drawn under its Visual: the ground shadow that
## stays behind while the car is in the air. PlayerCar reads `height`,
## `rotation_angle()` and `speed` every frame and frees this once `done`.

const GRAVITY := 2200.0
## Share of the climb speed the lip turns into lift.
const LAUNCH_KICK := 0.8
## Speeds clamp into this range for the whole jump.
const MIN_SPEED := 320.0
const MAX_SPEED := 1600.0
## Above this speed the car starts to backflip in the air, at
## `FLIP_RATE` turns per second per extra px/s.
const FLIP_START_SPEED := 650.0
const FLIP_RATE := 1.0 / 600.0
## A touchdown this hard bounces back up instead of settling.
const BOUNCE_MIN_IMPACT := 380.0
const BOUNCE_KEPT := 0.35
## Landing more than this far off upright is a crash.
const CRASH_ANGLE := deg_to_rad(70.0)
const CRASH_SPEED_KEPT := 0.6
## How far the ground can drop away in one frame and still be followed
## (rolling down the landing ramp) rather than flown off.
const LEAVE_GROUND_DROP := 24.0
## Past the ramp's right edge by this much, the car is clear of its footprint.
const RELEASE_MARGIN := 90.0
const PITCH_RESPONSE := 12.0
const UPRIGHT_RESPONSE := 10.0
const SHADOW_SIZE := Vector2(52.0, 9.0)

var ramp: RampEvent
var speed: float
var height := 0.0
var done := false

var _vertical_speed := 0.0
var _grounded := true
var _on_boards := false
var _has_landed := false
var _pitch := 0.0
var _spin := 0.0
var _flip_rate := 0.0
var _ground_height := 0.0

func _init(jump_ramp: RampEvent, entry_speed: float) -> void:
	ramp = jump_ramp
	speed = clampf(entry_speed, MIN_SPEED, MAX_SPEED)
	_flip_rate = -TAU * maxf(speed - FLIP_START_SPEED, 0.0) * FLIP_RATE

## The car's lean: its pitch along the slope or arc, plus any backflip.
func rotation_angle() -> float:
	return _pitch + _spin

## Advances the jump once the car has moved this frame. `blocked` when
## something other than the ramp stopped it dead.
func step(delta: float, blocked: bool) -> void:
	if blocked:
		speed = 0.0
	var local_x := ramp.to_local(global_position).x
	_ground_height = ramp.surface_height(local_x)
	if _grounded:
		_follow_ground(delta)
	else:
		_fly(delta)
	_pitch = lerp_angle(_pitch, _target_pitch(local_x), 1.0 - exp(-PITCH_RESPONSE * delta))
	if _has_landed:
		_spin = lerp_angle(_spin, 0.0, 1.0 - exp(-UPRIGHT_RESPONSE * delta))
	var clear_of_ramp := local_x > ramp.size.x / 2.0 + RELEASE_MARGIN or speed <= 0.0
	done = _grounded and _has_landed and height <= 0.0 and clear_of_ramp
	queue_redraw()

func _follow_ground(delta: float) -> void:
	if _ground_height < height - LEAVE_GROUND_DROP:
		_grounded = false
		_vertical_speed *= LAUNCH_KICK
		Sfx.play(&"ramp_whee", -6.0, 0.05)
		_fly(delta)
		return
	if _ground_height > 0.0 and not _on_boards:
		_on_boards = true
		Sfx.play(&"wood_clonk", -6.0, 0.1)
	_vertical_speed = (_ground_height - height) / delta
	height = _ground_height

func _fly(delta: float) -> void:
	_vertical_speed -= GRAVITY * delta
	height += _vertical_speed * delta
	_spin += _flip_rate * delta
	if height <= _ground_height and _vertical_speed < 0.0:
		_touch_down()

func _touch_down() -> void:
	var impact := -_vertical_speed
	height = _ground_height
	var crashed := not _has_landed and absf(wrapf(_spin, -PI, PI)) > CRASH_ANGLE
	_has_landed = true
	_flip_rate = 0.0
	if crashed:
		speed *= CRASH_SPEED_KEPT
		Sfx.play(&"collision", -2.0, 0.05)
		var car := get_parent() as PlayerCar
		if car != null:
			car.jiggle_visual()
	elif impact > BOUNCE_MIN_IMPACT:
		Sfx.play(&"gravel_crunch", -4.0, 0.1)
	else:
		Sfx.play(&"bump", -8.0, 0.1)
	if impact > BOUNCE_MIN_IMPACT:
		_vertical_speed = impact * BOUNCE_KEPT
	else:
		_vertical_speed = 0.0
		_grounded = true

## Nose along the deck while on it, along the arc while flying.
func _target_pitch(local_x: float) -> float:
	if _grounded:
		return atan(-ramp.surface_slope(local_x))
	return -atan2(_vertical_speed, maxf(speed, 1.0)) * 0.7

func _draw() -> void:
	if _grounded:
		return
	var lift := height - _ground_height
	var shrink := clampf(1.0 - lift / 500.0, 0.4, 1.0)
	draw_colored_polygon(FlatProps.octagon(Vector2(0.0, -_ground_height), SHADOW_SIZE.x * shrink, SHADOW_SIZE.y * shrink), UiPalette.SHADOW)
