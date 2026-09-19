class_name WorldCamera
extends Camera2D
## Mouse-wheel and trackpad zoom for the world map's driving camera.
## Scoped to the map only — the race scenes have their own CameraFollow
## with a fixed zoom, so this lives on PlayerCar's camera rather than
## being shared.
##
## Zoom eases toward a target rather than snapping, so spinning the
## wheel (or a trackpad gesture) doesn't jolt the view. `zoom` is a
## multiplier: higher = closer in.

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

var _target_zoom: float = 1.0

func _ready() -> void:
	_target_zoom = clampf(zoom.x, min_zoom, max_zoom)

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
	var current := zoom.x
	if is_equal_approx(current, _target_zoom):
		return
	var next := lerpf(current, _target_zoom, clampf(zoom_speed * delta, 0.0, 1.0))
	# Both axes together — unequal zoom would stretch the view.
	zoom = Vector2(next, next)
