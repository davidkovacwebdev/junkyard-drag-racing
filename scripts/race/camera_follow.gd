class_name CameraFollow
extends Camera2D
## The race camera. By default it follows the pack: the x of whichever
## tracked car is furthest along and the tracked cars' average y, until
## lock_on() parks it on the finish once the first car crosses.
##
## The player can take over at any time: mouse wheel zooms, dragging with any
## mouse button (or WASD / arrows) looks around freely, Tab rides along with
## one car after another, and R hands the camera back to the pack (or the
## finish, once it's locked).
##
## The camera eases toward where it wants to be every rendered frame instead of
## jumping there every physics step, ignores small vertical bounces, and always
## renders from a whole screen pixel. Any of those missing makes the static track
## (rocks, puddles, stripes, finish line) jitter or shimmer on screen.

enum Mode { PACK, ONE_CAR, FREE }
## Where "the pack" is: just ahead of the leader at the pack's average height
## (a flat track), the middle of the pack (an arena, where nobody's ahead), or
## up the slope ahead of the leader itself (a climb, where the stragglers are
## far below).
enum PackView { AHEAD_OF_LEADER, MIDDLE, UP_AHEAD_OF_LEADER }

var targets: Array[Node2D] = []
@export var pack_view: PackView = PackView.AHEAD_OF_LEADER

const LOCK_EASE := 4.0
## How fast (1/s) the camera catches up with the lead car.
const FOLLOW_EASE_X := 10.0
const FOLLOW_EASE_Y := 4.0
const VERTICAL_DEAD_ZONE := 40.0
const PACK_LEAD := 250.0
const ZOOM_STEP := 1.15
const ZOOM_EASE := 10.0
## Zoom limits, as multiples of the scene's starting zoom.
const ZOOM_RANGE := Vector2(0.4, 2.6)
## Screen pixels per second when looking around with the keys.
const KEY_PAN_SPEED := 900.0
## Screen pixels the mouse has to move before a press becomes a drag, so a
## plain click (dismissing the results) never nudges the view.
const DRAG_THRESHOLD := 6.0
const SWITCH_VOLUME_DB := -12.0

var _mode := Mode.PACK
var _followed_index := -1
var _locked := false
var _lock_position := Vector2.ZERO
var _has_snapped := false
## Where the camera really is, unrounded; global_position is this snapped to
## whole screen pixels.
var _smooth_position := Vector2.ZERO
## The height being followed. It only moves once the cars' average height
## leaves the dead zone around it, so bouncing never reaches the camera.
var _follow_y := 0.0
var _base_zoom := 1.0
var _target_zoom := 1.0
var _drag_pressed := false
var _dragging := false
var _drag_travel := 0.0
var _hint: RaceCameraHint

func _ready() -> void:
	_base_zoom = zoom.x
	_smooth_position = global_position
	_target_zoom = _base_zoom
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	_hint = RaceCameraHint.new()
	hud_layer.add_child(_hint)
	_refresh_hint()

func lock_on(position: Vector2) -> void:
	_locked = true
	_lock_position = position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _drag_pressed:
		_drag_travel += event.relative.length()
		if _drag_travel >= DRAG_THRESHOLD:
			_dragging = true
			_set_mode(Mode.FREE)
			_smooth_position -= event.relative / zoom
	elif event is InputEventPanGesture:
		_zoom_by(1.0 - event.delta.y * 0.01)
	elif event is InputEventMagnifyGesture:
		_zoom_by(event.factor)

## Keys go through _input so a focused button can't swallow Tab first. Any
## pan key while following switches to looking around, same as a drag.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_TAB:
			_follow_next_car()
		KEY_R:
			_set_mode(Mode.PACK)
			Sfx.play(&"binocular_focus", SWITCH_VOLUME_DB, 0.05)
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			_set_mode(Mode.FREE)
			return
		_:
			return
	get_viewport().set_input_as_handled()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_by(ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_by(1.0 / ZOOM_STEP)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			_drag_pressed = event.pressed
			if event.pressed:
				_drag_travel = 0.0
			elif _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()

func _zoom_by(factor: float) -> void:
	_target_zoom = clampf(_target_zoom * factor, _base_zoom * ZOOM_RANGE.x, _base_zoom * ZOOM_RANGE.y)

## Pack, then each car still in the race in turn, then back to the pack.
func _follow_next_car() -> void:
	var start := _followed_index if _mode == Mode.ONE_CAR else -1
	for step in range(1, targets.size() + 1):
		var index := start + step
		if index < targets.size() and is_instance_valid(targets[index]):
			_followed_index = index
			_set_mode(Mode.ONE_CAR)
			Sfx.play(&"binocular_focus", SWITCH_VOLUME_DB, 0.05)
			return
		if index >= targets.size():
			break
	_set_mode(Mode.PACK)
	Sfx.play(&"binocular_focus", SWITCH_VOLUME_DB, 0.05)

func _set_mode(mode: Mode) -> void:
	if mode == _mode and mode != Mode.ONE_CAR:
		return
	_mode = mode
	if mode != Mode.FREE:
		_follow_y = _smooth_position.y
	_refresh_hint()

func _refresh_hint() -> void:
	match _mode:
		Mode.PACK:
			_hint.set_status("Watching the pack")
		Mode.ONE_CAR:
			_hint.set_status("Riding with car %d of %d" % [_followed_index + 1, targets.size()])
		Mode.FREE:
			_hint.set_status("Looking around")

func _process(delta: float) -> void:
	_update_zoom(delta)
	match _mode:
		Mode.FREE:
			_pan_with_keys(delta)
		Mode.ONE_CAR:
			if _followed_index >= targets.size() or not is_instance_valid(targets[_followed_index]):
				_set_mode(Mode.PACK)
			else:
				_ease_toward(targets[_followed_index].global_position, delta)
		Mode.PACK:
			if _locked:
				_smooth_position = _smooth_position.lerp(_lock_position, 1.0 - exp(-LOCK_EASE * delta))
			else:
				var goal: Variant = _pack_goal()
				if goal != null:
					_ease_toward(goal, delta)
	_apply_position()

func _update_zoom(delta: float) -> void:
	var next := lerpf(zoom.x, _target_zoom, 1.0 - exp(-ZOOM_EASE * delta))
	zoom = Vector2(next, next)

func _pan_with_keys(delta: float) -> void:
	var direction := Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	_smooth_position += direction * KEY_PAN_SPEED / zoom.x * delta

func _ease_toward(goal: Vector2, delta: float) -> void:
	if not _has_snapped:
		_has_snapped = true
		_smooth_position = goal
		_follow_y = goal.y
		return
	var vertical_offset: float = goal.y - _follow_y
	if absf(vertical_offset) > VERTICAL_DEAD_ZONE:
		_follow_y += vertical_offset - signf(vertical_offset) * VERTICAL_DEAD_ZONE
	_smooth_position.x = lerpf(_smooth_position.x, goal.x, 1.0 - exp(-FOLLOW_EASE_X * delta))
	_smooth_position.y = lerpf(_smooth_position.y, _follow_y, 1.0 - exp(-FOLLOW_EASE_Y * delta))

func _apply_position() -> void:
	global_position = (_smooth_position * zoom).round() / zoom

## See PackView. Null when nothing tracked is left.
func _pack_goal() -> Variant:
	var leader: Node2D = null
	var total := Vector2.ZERO
	var count := 0
	for target in targets:
		if not is_instance_valid(target):
			continue
		if leader == null or target.global_position.x > leader.global_position.x:
			leader = target
		total += target.global_position
		count += 1
	if count == 0:
		return null
	match pack_view:
		PackView.MIDDLE:
			return total / count
		PackView.UP_AHEAD_OF_LEADER:
			return leader.global_position + Vector2(PACK_LEAD, -PACK_LEAD) * 0.5
	return Vector2(leader.global_position.x + PACK_LEAD, total.y / count)
