class_name ResultsScreen
extends Control
## Podium shown once a race ends: place, name, and a live icon of the car's
## body — reuses PartIcon (see garage/part_icon.gd) instead of drawing
## bespoke car art, the same SubViewport-snapshot trick the garage's part
## catalog already uses.

const PART_ICON_SCENE := preload("res://scenes/garage/part_icon.tscn")
const ROW_ICON_SIZE := Vector2(40.0, 40.0)
const ROW_SEPARATION := 12

@onready var _panel: Control = $Panel
@onready var _margin: MarginContainer = $Panel/Margin
@onready var _rows: VBoxContainer = $Panel/Margin/Layout/Rows
@onready var _earnings: VBoxContainer = $Panel/Margin/Layout/Earnings

func _ready() -> void:
	visible = false

## `standings` holds the top 3 places, plus the player's own when lower, each
## a Dictionary with "place" (1-based), "name" (already resolved to "You" or
## a driver name), "body_part_data" (may be null) and "kills".
## `earnings` is what the player made, each {"label", "amount"}.
func show_results(standings: Array[Dictionary], earnings: Array[Dictionary]) -> void:
	for child in _rows.get_children() + _earnings.get_children():
		child.queue_free()
	for entry in standings:
		_add_row(entry)
	for earning in earnings:
		var earning_label := _label("%s  +$%d" % [earning["label"], earning["amount"]], UiPalette.TEXT_BROWN, 16)
		earning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_earnings.add_child(earning_label)
	_earnings.visible = not earnings.is_empty()
	visible = true
	_fit_panel.call_deferred()

## The board grows and shrinks to hold however many rows it got.
func _fit_panel() -> void:
	var half_height := _margin.get_combined_minimum_size().y * 0.5
	_panel.offset_top = -half_height
	_panel.offset_bottom = half_height

func _add_row(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	_rows.add_child(row)

	var place_label := _label(_ordinal(entry.get("place", 0)), UiPalette.ACCENT_YELLOW, 20)
	place_label.custom_minimum_size = Vector2(40.0, 0.0)
	row.add_child(place_label)

	# Added to the tree before show_part() so its @onready SubViewport
	# reference is already resolved (PartIcon only wires it up on _ready).
	var icon: PartIcon = PART_ICON_SCENE.instantiate()
	icon.custom_minimum_size = ROW_ICON_SIZE
	row.add_child(icon)
	icon.show_part(entry.get("body_part_data"))

	var name_label := _label(entry.get("name", "???"), UiPalette.TEXT_BROWN, 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var kills: int = entry.get("kills", 0)
	if kills > 0:
		row.add_child(_label("%d KO" % kills, UiPalette.DANGER_RED, 16))

func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

static func _ordinal(place: int) -> String:
	var suffix := "th"
	if place % 100 < 11 or place % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][place % 10]
	return "%d%s" % [place, suffix]
