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

## The scene-authored panel style, captured once and never itself
## mutated — every recolor reads its border/bg as the "neutral" baseline
## to tween to/from, so a slot that cycles through parts (or back to no
## part at all) never drifts from the original border width/corner
## radius. `_style` is the single live instance actually applied as the
## panel override; animating its bg_color in place (rather than swapping
## in a fresh StyleBox each time) is what makes the hover tween possible.
var _base_panel_style: StyleBoxFlat
var _style: StyleBoxFlat
var _hover_tween: Tween
var _hovering: bool = false

## How far the background eases toward the tier color on hover. Hue
## barely moves (a wash of color reads as gaudy against the neutral
## panel) — opacity moves much further, so a hovered row reads as
## brighter/lit-up rather than differently colored.
const _HOVER_RGB_MIX := 0.18
const _HOVER_ALPHA_MIX := 0.5
const _HOVER_TRANSITION := 0.12

func _ready() -> void:
	_base_panel_style = get_theme_stylebox("panel") as StyleBoxFlat
	if _base_panel_style != null:
		_style = _base_panel_style.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	_hovering = true
	_animate_background()

func _on_mouse_exited() -> void:
	_hovering = false
	_animate_background()

func set_part(new_part: PartData, count: int = 1) -> void:
	part = new_part
	_icon.show_part(part.scene_path if part != null else "")
	_title_label.text = _title_for(part, count)
	_durability_bar.set_rating(_rating(part.durability, PartData.DURABILITY_RANGE) if part != null else 0)
	_speed_bar.set_rating(_rating(part.speed, PartData.SPEED_RANGE) if part != null else 0)
	_mass_bar.set_rating(_rating(part.mass, PartData.MASS_RANGE) if part != null else 0)
	if _style != null:
		_style.border_color = PartData.tier_color(part.tier) if part != null else _base_panel_style.border_color
	_animate_background()

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

## Eases the background toward (or back from) a faint tint of the part's
## tier color. Always tweens from wherever bg_color currently sits, so a
## hover that lands mid-transition (or a part swap while already
## hovered) redirects smoothly instead of snapping.
func _animate_background() -> void:
	if _style == null or _base_panel_style == null:
		return
	var base := _base_panel_style.bg_color
	var target := base
	if _hovering and part != null:
		var tint := PartData.tier_color(part.tier)
		target = Color(
			lerpf(base.r, tint.r, _HOVER_RGB_MIX),
			lerpf(base.g, tint.g, _HOVER_RGB_MIX),
			lerpf(base.b, tint.b, _HOVER_RGB_MIX),
			lerpf(base.a, tint.a, _HOVER_ALPHA_MIX))
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_style, "bg_color", target, _HOVER_TRANSITION)

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
