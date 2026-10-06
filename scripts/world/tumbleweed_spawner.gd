class_name TumbleweedSpawner
extends CritterSpawner
## Now and then sends a tumbleweed bouncing across the desert. Each comes in
## from the left or right edge of the view and rolls across the screen with a
## mostly sideways wind; after that it roams the desert on its own (see
## Tumbleweed).

## The wind's slant for a tumbleweed coming in from the left; ones from the
## right get it mirrored.
@export var wind_direction := Vector2(1.0, 0.15)
@export var speed_range := Vector2(90.0, 160.0)

var _incoming_wind := Vector2.RIGHT

func _is_good_spot(global_point: Vector2) -> bool:
	var point := _terrain.to_local(global_point)
	return _terrain.is_on_land(point) and _terrain.biome_at(point) == TerrainBiome.Kind.DESERT

func _spawn_at(global_point: Vector2) -> Array[Node2D]:
	var tumbleweed := Tumbleweed.new()
	tumbleweed.position = global_point
	tumbleweed.wind = _incoming_wind * randf_range(speed_range.x, speed_range.y)
	tumbleweed.terrain = _terrain
	return [tumbleweed]

## The upwind edge for a wind picked here, blowing left or right at random.
func _spot_outside(view: Rect2) -> Vector2:
	var side := 1.0 if randf() < 0.5 else -1.0
	_incoming_wind = Vector2(wind_direction.x * side, wind_direction.y).normalized()
	var start := view.get_center() + Vector2(0.0, randf_range(-0.45, 0.45) * view.size.y)
	return _edge_beyond(view, start, -_incoming_wind)
