class_name WheelMountZone
extends Control
## Small, transparent drop target sitting over one of the body's wheel
## mounts. Drop a wheel part here to bolt it onto that specific mount,
## instead of the old single "wheels" slot that stamped the same wheel on
## every mount. Dragging from it pulls that mount's wheel off instead.

var garage: Garage
var wheel_index: int = -1

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("category") == PartData.Category.WHEEL \
			and not data.get("fitted", false)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if garage != null:
		garage.equip_part(PartData.Category.WHEEL, data["part"], wheel_index)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if garage == null:
		return null
	return garage.fitted_wheel_drag(self, wheel_index)
