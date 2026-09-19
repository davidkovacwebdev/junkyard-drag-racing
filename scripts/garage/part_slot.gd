class_name PartSlot
extends VBoxContainer
## A part row that's both a drag source and a drop target — used for
## every catalog list row AND for the car's own equipped-part icons.
## Dragging a catalog row onto the car equips it; dragging the car's
## current part onto a catalog row does the exact same equip, just
## started from the other side ("vice versa") — whichever PartSlot
## receives the drop just tells `garage` to equip the dragged part into
## the currently-viewed car's matching category, regardless of which
## slot it lands on.

var category: PartData.Category
var part: PartData
var garage: Garage

@onready var _icon: PartIcon = $Icon
@onready var _name_label: Label = $NameLabel

func set_part(new_part: PartData) -> void:
	part = new_part
	_icon.show_part(part.scene_path if part != null else "")
	_name_label.text = part.display_name if part != null else "—"

func _get_drag_data(_at_position: Vector2) -> Variant:
	if part == null:
		return null
	# Reuse the icon's own already-rendered texture as the preview, so
	# what follows the cursor is the actual part, not just its name.
	var preview := TextureRect.new()
	preview.texture = _icon.get_preview_texture()
	preview.custom_minimum_size = Vector2(64, 64)
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"category": category, "part": part}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("category") == category

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if garage != null:
		garage.equip_part(category, data["part"])
