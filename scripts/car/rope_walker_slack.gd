class_name RopeWalkerSlack
extends RefCounted
## Lets a rope engine's walker (HorseEngine's horse, PunkerEngine's runner)
## hang off the car on its rope instead of being bolted to it. The walker's
## spot out in front of the car is only where it wants to be: a damped spring
## in world space pulls it there, so it lags when the car lurches, bounces on
## landings and swings wide through turns, and its heading catches up with the
## car's a beat late. Steady driving leaves it right on its spot.
##
## Visual only: collisions and the drive still use the rigid spot.

const STIFFNESS := 90.0
const DAMPING := 11.0
## Furthest the walker strays from its spot before the rope yanks it along,
## in the walker's parent's pixels.
const MAX_SLACK := 26.0
## A jump this many times MAX_SLACK is a teleport (race reset, map warp, the
## view refitting itself), not driving: snap instead of swinging across.
const SNAP_FACTOR := 4.0
const TURN_CATCH_UP := 9.0
const MAX_TURN_LAG := 0.35

var _walker: Node2D
var _rest_position: Vector2
var _rest_rotation: float
var _position: Vector2
var _velocity: Vector2
var _previous_target: Vector2
var _heading: float
var _mirrored := false
var _settled := false

func _init(walker: Node2D) -> void:
	_walker = walker
	_rest_position = walker.position
	_rest_rotation = walker.rotation

func update(delta: float) -> void:
	var parent := _walker.get_parent() as Node2D
	var frame := parent.global_transform
	var mirrored := frame.determinant() < 0.0
	var mirror_sign := -1.0 if mirrored else 1.0
	var world_scale := frame.x.length()
	var target := frame * _rest_position
	var frame_heading := (frame.x * mirror_sign).angle()
	var max_slack := MAX_SLACK * world_scale
	if not _settled or mirrored != _mirrored or _position.distance_to(target) > max_slack * SNAP_FACTOR:
		_snap(target, frame_heading, mirrored)
	else:
		var target_velocity := (target - _previous_target) / delta
		var acceleration := (target - _position) * STIFFNESS - (_velocity - target_velocity) * DAMPING
		_velocity += acceleration * delta
		_position += _velocity * delta
		var offset := _position - target
		if offset.length() > max_slack:
			_position = target + offset.limit_length(max_slack)
		_heading = lerp_angle(_heading, frame_heading, clampf(TURN_CATCH_UP * delta, 0.0, 1.0))
		_heading = frame_heading + clampf(angle_difference(frame_heading, _heading), -MAX_TURN_LAG, MAX_TURN_LAG)
	_previous_target = target
	_walker.position = frame.affine_inverse() * _position
	_walker.rotation = _rest_rotation + angle_difference(frame_heading, _heading) * mirror_sign

func _snap(target: Vector2, frame_heading: float, mirrored: bool) -> void:
	_position = target
	_velocity = Vector2.ZERO
	_heading = frame_heading
	_mirrored = mirrored
	_settled = true
