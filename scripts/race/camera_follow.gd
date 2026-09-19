class_name CameraFollow
extends Camera2D
## Follows the x-position of whichever tracked car is furthest along,
## averaging the tracked cars' y so both lanes stay roughly in frame —
## until lock_on() is called, at which point it eases to and holds a
## fixed point instead (used once the first car crosses the finish line,
## so the camera just stays put on the finish/wall area for the crash
## instead of continuing to chase whoever's still racing).

var targets: Array[Node2D] = []

var _locked := false
var _lock_position := Vector2.ZERO
const LOCK_EASE := 4.0

func lock_on(position: Vector2) -> void:
	_locked = true
	_lock_position = position

func _physics_process(delta: float) -> void:
	if _locked:
		global_position = global_position.lerp(_lock_position, clampf(LOCK_EASE * delta, 0.0, 1.0))
		return

	if targets.is_empty():
		return
	var lead_x := -INF
	var avg_y := 0.0
	var count := 0
	for target in targets:
		if not is_instance_valid(target):
			continue
		lead_x = max(lead_x, target.global_position.x)
		avg_y += target.global_position.y
		count += 1
	if count == 0:
		return
	global_position = Vector2(lead_x + 250.0, avg_y / count)
