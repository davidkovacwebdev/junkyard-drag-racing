class_name WheelPartData
extends PartData
## The rolling shape itself lives in the wheel's own scene
## (CollisionPolygon2D/Polygon2D) — that shape IS the wheel's handling.

func _init() -> void:
	category = Category.WHEEL
