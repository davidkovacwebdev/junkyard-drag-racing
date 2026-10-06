class_name GullSpawner
extends CritterSpawner
## Keeps a few seagulls standing about on the beaches near the camera, in ones,
## twos and threes. A spot counts as beach when it's on land with open water
## within `beach_reach`. The gulls take off when the car comes close (see Bird).

@export var beach_reach: float = 220.0
@export var flock_size := Vector2i(1, 3)
@export var flock_spread := Vector2(70.0, 36.0)

const SHORE_SAMPLES := 8

func _is_good_spot(global_point: Vector2) -> bool:
	var point := _terrain.to_local(global_point)
	if not _terrain.is_on_land(point):
		return false
	for i in SHORE_SAMPLES:
		if not _terrain.is_on_land(point + Vector2.from_angle(TAU * i / SHORE_SAMPLES) * beach_reach):
			return true
	return false

func _spawn_at(global_point: Vector2) -> Array[Node2D]:
	var flock: Array[Node2D] = []
	for i in randi_range(flock_size.x, flock_size.y):
		var gull := Bird.new()
		gull.species = Bird.Species.GULL
		gull.position = global_point + Vector2(randf_range(-1.0, 1.0) * flock_spread.x, randf_range(-1.0, 1.0) * flock_spread.y)
		flock.append(gull)
	return flock
