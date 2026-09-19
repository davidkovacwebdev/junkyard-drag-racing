class_name WheelMountZone
extends Control
## Small, transparent drop target sitting over one of the body's wheel
## mounts. Drop a wheel part here to bolt it onto that specific mount,
## instead of the old single "wheels" slot that stamped the same wheel on
## every mount.

var garage: Garage
var wheel_index: int = -1

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("category") == PartData.Category.WHEEL

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if garage != null:
		garage.equip_part(PartData.Category.WHEEL, data["part"], wheel_index)
