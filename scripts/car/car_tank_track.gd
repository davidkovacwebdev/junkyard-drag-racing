class_name CarTankTrack
extends CarWheel
## A tank track. The belt stays level under the car while the road wheels
## inside it turn with the roll. Its collision is one round wheel as tall as
## the belt, so it drives like a wheel and looks like a track.

## Radius of the round collision the track rolls on.
@export var belt_radius: float = 30.0
@export var road_wheel_radius: float = 17.0

@onready var _belt: Node2D = $Belt
@onready var _road_wheels: Array[Node2D] = _find_road_wheels()

func _process(delta: float) -> void:
	if chassis == null or not is_instance_valid(chassis):
		return
	_belt.global_rotation = chassis.global_rotation
	_spin_road_wheels(angular_velocity * delta * belt_radius / road_wheel_radius)

## Overrides CarWheel.animate_visual: on the map only the road wheels turn.
func animate_visual(distance: float, _delta: float) -> void:
	if distance == 0.0:
		return
	_spin_road_wheels(distance / (road_wheel_radius * maxf(absf(global_scale.x), 0.0001)))

func _spin_road_wheels(angle: float) -> void:
	for road_wheel in _road_wheels:
		road_wheel.rotation += angle

func _find_road_wheels() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for child in _belt.get_children():
		if child.name.begins_with("RoadWheel"):
			found.append(child)
	return found
