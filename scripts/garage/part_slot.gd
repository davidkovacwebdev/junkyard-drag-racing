class_name PartSlot
extends PanelContainer
## A part row that's both a drag source and a drop target — used for
## every catalog list row. Dragging it onto the car equips it; dragging
## the car's own part onto a catalog row does the exact same equip,
## just started from the other side — whichever PartSlot receives the
## drop just tells `garage` to equip the dragged part into the
## currently-viewed car's matching category, regardless of which slot
## it lands on. A wheel dropped here has no mount to aim at, so it takes
## the first mount not already wearing it, one drop per mount.
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

## Cardboard card behind the row (see the ui-style skill). The tier shows as a
## strip of coloured tape across the top-right corner, not a border.
var _board := ScrapBoard.new()
var _hovering: bool = false

const _TAPE_SIZE := Vector2(46.0, 12.0)
const _TAPE_ANGLE := deg_to_rad(28.0)
const _ICON_GAP_MARGIN := 4.0

func _ready() -> void:
	_board.jitter = 2.0
	_board.nails = false
	mouse_entered.connect(_set_hovering.bind(true))
	mouse_exited.connect(_set_hovering.bind(false))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_SORT_CHILDREN:
		queue_redraw()

func _set_hovering(value: bool) -> void:
	_hovering = value
	queue_redraw()

func set_part(new_part: PartData, count: int = 1) -> void:
	part = new_part
	_icon.show_part(part.scene_path if part != null else "")
	_title_label.text = _title_for(part, count)
	_durability_bar.set_rating(_rating(part.durability, PartData.DURABILITY_RANGE) if part != null else 0)
	_speed_bar.set_rating(_rating(part.speed, PartData.SPEED_RANGE) if part != null else 0)
	_mass_bar.set_rating(_rating(part.mass, PartData.MASS_RANGE) if part != null else 0)
	queue_redraw()

## "Standard Wheel x2" — how many copies of this part the player owns, fitted
## or loose. Fitting MOVES a copy rather than cloning one, so the count is what
## tells four tires apart from one; without it a lone tire looks like it should
## be able to fill the car. One copy is the normal case, so it stays quiet.
static func _title_for(shown: PartData, show_count: int) -> String:
	if shown == null:
		return "—"
	if show_count <= 1:
		return shown.display_name
	return "%s x%d" % [shown.display_name, show_count]

static func _rating(value: float, stat_range: Vector2) -> int:
	var t := clampf((value - stat_range.x) / (stat_range.y - stat_range.x), 0.0, 1.0)
	return clampi(int(round(t * 4.0)) + 1, 1, 5)

func _draw() -> void:
	var seed := hash(part.id) if part != null else 0
	_board.jitter_seed = seed
	_board.tilt_degrees = float(posmod(seed, 17) - 8) / 10.0
	_board.body_color = UiPalette.CARDBOARD_LIGHT if _hovering and part != null else UiPalette.CARDBOARD_BASE
	_board.shade_color = UiPalette.CARDBOARD_SHADE
	_board.skirt_color = UiPalette.CARDBOARD_DARK
	_board.draw(self, Rect2(Vector2.ZERO, size))

	var icon_rect := Rect2(_icon.global_position - global_position, _icon.size)
	draw_rect(icon_rect.grow(_ICON_GAP_MARGIN), UiPalette.SURFACE_DARK)

	if part != null:
		var tape_centre := Vector2(size.x - _TAPE_SIZE.x * 0.45, _TAPE_SIZE.y * 0.6)
		var tape := PackedVector2Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			tape.append(tape_centre + (corner * _TAPE_SIZE * 0.5).rotated(_TAPE_ANGLE))
		draw_colored_polygon(tape, PartData.tier_color(part.tier))

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
