class_name WheelPartData
extends PartData
## The rolling shape itself lives in the wheel's own scene
## (CollisionPolygon2D/Polygon2D) — that shape IS the wheel's handling.

## 0..1 share of bump and landing damage this wheel soaks up, like suspension:
## for itself, and averaged with the other wheels for the body it carries.
@export_range(0.0, 1.0) var absorption: float = 0.0
## Turns up as loot in bins, junk heaps and on the fishing line. Off for a
## wheel the story hands over (Grandpa's helmet).
@export var found_in_junk: bool = true

func _init() -> void:
	category = Category.WHEEL
