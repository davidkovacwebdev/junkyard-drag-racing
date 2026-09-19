class_name WorldCamera
extends Camera2D
## Mouse-wheel zoom for the world map's driving camera. Scoped to the map
## only — the race scenes have their own CameraFollow with a fixed zoom,
## so this lives on PlayerCar's camera rather than being shared.
##
## Zoom eases toward a target rather than snapping, so spinning the wheel
## doesn't jolt the view. `zoom` is a multiplier: higher = closer in.

@export var zoom_step: float = 1.15
@export var min_zoom: float = 0.25
@export var max_zoom: float = 3.0
## Higher eases faster; 0 would never arrive.
@export var zoom_speed: float = 10.0

var _target_zoom: float = 1.0

func _ready() -> void:
	_target_zoom = clampf(zoom.x, min_zoom, max_zoom)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.is_pressed():
		return
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / zoom_step)
		_:
			return
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
