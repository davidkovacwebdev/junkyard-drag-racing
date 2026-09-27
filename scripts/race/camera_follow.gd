class_name CameraFollow
extends Camera2D
## Follows the x-position of whichever tracked car is furthest along,
## averaging the tracked cars' y so both lanes stay roughly in frame —
## until lock_on() is called, at which point it eases to and holds a
## fixed point instead (used once the first car crosses the finish line,
## so the camera just stays put on the finish/wall area for the crash
## instead of continuing to chase whoever's still racing).

## The camera eases toward where it wants to be every rendered frame instead of
## jumping there every physics step, ignores small vertical bounces, and always
## renders from a whole screen pixel. Any of those missing makes the static track
## (rocks, puddles, stripes, finish line) jitter or shimmer on screen.

var targets: Array[Node2D] = []

var _locked := false
var _lock_position := Vector2.ZERO
var _has_snapped := false
## Where the camera really is, unrounded; global_position is this snapped to
## whole screen pixels.
var _smooth_position := Vector2.ZERO
## The height being followed. It only moves once the cars' average height
## leaves the dead zone around it, so bouncing never reaches the camera.
var _follow_y := 0.0
const LOCK_EASE := 4.0
## How fast (1/s) the camera catches up with the lead car.
const FOLLOW_EASE_X := 10.0
const FOLLOW_EASE_Y := 4.0
const VERTICAL_DEAD_ZONE := 40.0

func lock_on(position: Vector2) -> void:
	_locked = true
	_lock_position = position

func _process(delta: float) -> void:
	if _locked:
		_smooth_position = _smooth_position.lerp(_lock_position, 1.0 - exp(-LOCK_EASE * delta))
		_apply_position()
		return
	var goal: Variant = _follow_goal()
	if goal == null:
		return
	if not _has_snapped:
		_has_snapped = true
		_smooth_position = goal
		_follow_y = goal.y
		_apply_position()
		return
	var vertical_offset: float = goal.y - _follow_y
	if absf(vertical_offset) > VERTICAL_DEAD_ZONE:
		_follow_y += vertical_offset - signf(vertical_offset) * VERTICAL_DEAD_ZONE
	_smooth_position.x = lerpf(_smooth_position.x, goal.x, 1.0 - exp(-FOLLOW_EASE_X * delta))
	_smooth_position.y = lerpf(_smooth_position.y, _follow_y, 1.0 - exp(-FOLLOW_EASE_Y * delta))
	_apply_position()

func _apply_position() -> void:
	global_position = (_smooth_position * zoom).round() / zoom

## Just ahead of the lead car, at the tracked cars' average height. Null when
## nothing tracked is left.
func _follow_goal() -> Variant:
	var lead_x := -INF
	var total_y := 0.0
	var count := 0
	for target in targets:
		if not is_instance_valid(target):
			continue
		lead_x = maxf(lead_x, target.global_position.x)
		total_y += target.global_position.y
		count += 1
	if count == 0:
		return null
	return Vector2(lead_x + 250.0, total_y / count)
