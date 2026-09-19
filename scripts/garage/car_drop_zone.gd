class_name CarDropZone
extends Control
## Big, forgiving drop target covering the whole car-preview side of the
## garage. The precise BodySlot/EngineSlot/WheelSlot icons are still
## valid, exact drop targets on top of this — but dropping anywhere else
## in this area (including right on the car picture itself, which is a
## Node2D and can't be a drop target on its own) still equips the part,
## routed by whatever category the dragged data itself carries.

var garage: Garage

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("category") and data.has("part")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if garage != null:
		garage.equip_part(data["category"], data["part"])
