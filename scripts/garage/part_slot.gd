class_name PartSlot
extends PanelContainer
## A part row that's both a drag source and a drop target — used for
## every catalog list row. Dragging it onto the car equips it; dragging
## the car's own part onto a catalog row does the exact same equip,
## just started from the other side — whichever PartSlot receives the
## drop just tells `garage` to equip the dragged part into the
## currently-viewed car's matching category, regardless of which slot
## it lands on.
##
## Layout: icon on the left, title + Durability/Speed/Mass stat bars
## on the right.

var category: PartData.Category
var part: PartData
var garage: Garage

@onready var _icon: PartIcon = $Row/Icon
@onready var _title_label: Label = $Row/Info/TitleLabel
@onready var _durability_bar: StatBar = $Row/Info/DurabilityRow/DurabilityBar
@onready var _speed_bar: StatBar = $Row/Info/SpeedRow/SpeedBar
@onready var _mass_bar: StatBar = $Row/Info/MassRow/MassBar

## Calibrated against the actual min/max seen across the current part
## catalog (see the "speed = " values authored on each part scene, and
## the mass/durability survey behind them) — not a physical unit, just
## enough spread that a 1 and a 5 both show up somewhere in the catalog.
const _MASS_RANGE := Vector2(3.0, 22.0)
const _DURABILITY_RANGE := Vector2(20.0, 140.0)
const _SPEED_RANGE := Vector2(0.5, 8.0)

func set_part(new_part: PartData) -> void:
	part = new_part
	_icon.show_part(part.scene_path if part != null else "")
	_title_label.text = part.display_name if part != null else "—"
	_durability_bar.set_rating(_rating(part.durability, _DURABILITY_RANGE) if part != null else 0)
	_speed_bar.set_rating(_rating(part.speed, _SPEED_RANGE) if part != null else 0)
	_mass_bar.set_rating(_rating(part.mass, _MASS_RANGE) if part != null else 0)

static func _rating(value: float, stat_range: Vector2) -> int:
	var t := clampf((value - stat_range.x) / (stat_range.y - stat_range.x), 0.0, 1.0)
	return clampi(int(round(t * 4.0)) + 1, 1, 5)

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
