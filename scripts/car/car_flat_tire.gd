class_name CarFlatTire
extends CarWheel
## A tyre gone flat. The squashed rubber stays pinned flat side down under the
## car while only the hub turns inside it. Its collision is a lumpy 7-gon, so
## the car thumps along like it's riding on the rim.

@onready var _tyre: Node2D = $Tyre
@onready var _hub: Node2D = $Hub

func _process(_delta: float) -> void:
	if chassis != null and is_instance_valid(chassis):
		_tyre.global_rotation = chassis.global_rotation

## Overrides CarWheel.animate_visual: on the map only the hub turns.
func animate_visual(distance: float, _delta: float) -> void:
	if distance == 0.0:
		return
	_hub.rotation += distance / visual_roll_radius()
