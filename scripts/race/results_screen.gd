class_name ResultsScreen
extends Control
## Podium shown once a race ends: place, name, and a live icon of the car's
## body — reuses PartIcon (see garage/part_icon.gd) instead of drawing
## bespoke car art, the same SubViewport-snapshot trick the garage's part
## catalog already uses.

const PART_ICON_SCENE := preload("res://scenes/garage/part_icon.tscn")
const PLACE_LABELS := ["1st", "2nd", "3rd"]
const ROW_ICON_SIZE := Vector2(40.0, 40.0)
const ROW_SEPARATION := 12

@onready var _rows: VBoxContainer = $Panel/Margin/Layout/Rows

func _ready() -> void:
	visible = false

## `standings` holds up to 3 places in order, each a Dictionary with
## "name" (already resolved to "Player" or a random opponent name) and
## "icon_scene_path" (the car body's scene, may be empty).
func show_results(standings: Array[Dictionary]) -> void:
	for child in _rows.get_children():
		child.queue_free()
	for i in mini(standings.size(), PLACE_LABELS.size()):
		_add_row(PLACE_LABELS[i], standings[i])
	visible = true

func _add_row(place_text: String, entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	_rows.add_child(row)

	var place_label := Label.new()
	place_label.text = place_text
	place_label.custom_minimum_size = Vector2(40.0, 0.0)
	place_label.add_theme_color_override("font_color", UiPalette.ACCENT_YELLOW)
	place_label.add_theme_font_size_override("font_size", 20)
	place_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(place_label)

	# Added to the tree before show_part() so its @onready SubViewport
	# reference is already resolved (PartIcon only wires it up on _ready).
	var icon: PartIcon = PART_ICON_SCENE.instantiate()
	icon.custom_minimum_size = ROW_ICON_SIZE
	row.add_child(icon)
	icon.show_part(entry.get("icon_scene_path", ""))

	var name_label := Label.new()
	name_label.text = entry.get("name", "???")
	name_label.add_theme_color_override("font_color", UiPalette.TEXT_BROWN)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
