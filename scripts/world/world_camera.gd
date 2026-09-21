class_name WorldCamera
extends Camera2D
## Mouse-wheel/trackpad zoom, plus a look-ahead offset, for the world
## map's driving camera. Scoped to the map only — the race scenes have
## their own CameraFollow with a fixed zoom, so this lives on PlayerCar's
## camera rather than being shared.
##
## Zoom eases toward a target rather than snapping, so spinning the
## wheel (or a trackpad gesture) doesn't jolt the view. `zoom` is a
## multiplier: higher = closer in.
##
## Look-ahead is deliberately built on Camera2D.offset rather than
## position_smoothing: smoothing only ever lags behind the tracked
## position (so moving left actually reveals more of the right — where
## you came from, not where you're going), while offsetting the view
## toward the car's current velocity reveals more of the direction of
## travel instead. position_smoothing is left off (see player_car.tscn).

@export var zoom_step: float = 1.15
@export var min_zoom: float = 0.25
@export var max_zoom: float = 3.0
## Higher eases faster; 0 would never arrive.
@export var zoom_speed: float = 10.0
## How much each unit of trackpad two-finger-scroll delta affects zoom.
## A scroll gesture fires many small continuous events (unlike a mouse
## wheel's one notch per click), so this needs to be far gentler than
## zoom_step or a single swipe would blow straight through the range.
@export var pan_sensitivity: float = 0.01

## How far, in pixels, the view shifts toward the car's direction of
## travel at full speed.
@export var look_ahead_distance: float = 90.0
## How quickly the offset eases toward its target as speed/direction
## changes — higher settles faster.
@export var look_ahead_speed: float = 1.2

var _target_zoom: float = 1.0
var _car: CharacterBody2D

func _ready() -> void:
	_target_zoom = clampf(zoom.x, min_zoom, max_zoom)
	_car = get_parent() as CharacterBody2D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.0 / zoom_step)
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		# Trackpad two-finger scroll — same sense as the mouse wheel:
		# scrolling up zooms in. Continuous deltas, so scale gently
		# instead of applying a full zoom_step per event.
		_zoom_by(1.0 - event.delta.y * pan_sensitivity)
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		# Trackpad pinch — factor is already a small per-event
		# multiplier (>1 spreading/zooming in, <1 pinching/zooming out).
		_zoom_by(event.factor)
		get_viewport().set_input_as_handled()

func _zoom_by(factor: float) -> void:
	_target_zoom = clampf(_target_zoom * factor, min_zoom, max_zoom)

func _process(delta: float) -> void:
	_update_zoom(delta)
	_update_look_ahead(delta)

func _update_zoom(delta: float) -> void:
	var current := zoom.x
	if is_equal_approx(current, _target_zoom):
		return
	var next := lerpf(current, _target_zoom, clampf(zoom_speed * delta, 0.0, 1.0))
	# Both axes together — unequal zoom would stretch the view.
	zoom = Vector2(next, next)

## Shifts the view toward wherever the car is currently headed, scaled by
## how fast it's actually moving (full speed = full look_ahead_distance;
## at rest the offset eases back to zero instead of freezing wherever it
## last pointed).
func _update_look_ahead(delta: float) -> void:
	if _car == null:
		return
	var speed_fraction := clampf(_car.velocity.length() / maxf(_car.max_speed, 1.0), 0.0, 1.0)
	var target_offset := Vector2.ZERO
	if _car.velocity.length() > 1.0:
		target_offset = _car.velocity.normalized() * look_ahead_distance * speed_fraction
	offset = offset.lerp(target_offset, clampf(look_ahead_speed * delta, 0.0, 1.0))
