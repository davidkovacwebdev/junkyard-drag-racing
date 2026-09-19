class_name CarDropZone
extends Control
## Big, forgiving drop target covering the whole car-preview side of the
## garage. The per-mount wheel targets sit on top of this and handle wheel
## drops themselves; this zone catches BODY and ENGINE drops anywhere in
## the preview area (including right on the car picture itself, which is a
## Node2D and can't be a drop target on its own).

var garage: Garage

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var category = data.get("category")
	return category == PartData.Category.BODY or category == PartData.Category.ENGINE

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if garage != null:
		garage.equip_part(data["category"], data["part"])
