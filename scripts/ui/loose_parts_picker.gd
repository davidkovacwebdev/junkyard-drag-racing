class_name LoosePartsPicker
extends Control
## The loose-parts list the pan factory and the recycler share: the garage's
## Car Body / Engines / Wheels / Extras tabs and its sort button over one
## PartSlot row per part id (with how many loose copies there are). Clicking a
## row picks a copy (`part_picked`).
##
## Only loose parts (Inventory.spare_parts); a part has to come off the car in
## the garage first. Rows are built the first time a part shows up and kept,
## because each holds a live SubViewport icon; a screen that changes a part's
## look calls `drop_row()` so it's rebuilt.

signal part_picked(part: PartData)

const _PART_SLOT_SCENE := preload("res://scenes/garage/part_slot.tscn")
const CATEGORIES := [PartData.Category.BODY, PartData.Category.ENGINE, PartData.Category.WHEEL, PartData.Category.ACCESSORY]
## The garage's filter tab names.
const TAB_NAMES := ["Car Body", "Engines", "Wheels", "Extras"]
const EMPTY_HINTS := {
	PartData.Category.BODY: "No loose car bodies.\nTake one off in the garage,\nor dig one up at the junkyard.",
	PartData.Category.ENGINE: "No loose engines.\nTake one off in the garage,\nor dig one up at the junkyard.",
	PartData.Category.WHEEL: "No loose wheels.\nTake some off in the garage,\nor dig some up at the junkyard.",
	PartData.Category.ACCESSORY: "No loose extras.\nTake some off in the garage,\nor dig some up at the junkyard.",
}
const LIST_TOP := 92.0

## What the list's title says picking a part does.
@export var title: String = "LOOSE PARTS (click to pick)"
## First 4 ScrapButton jitter seeds for the tabs, so two screens don't look
## stamped out of the same sheet.
@export var seed_base: int = 101

var category: PartData.Category = PartData.Category.BODY
## The copy this screen is working on, listed first among its id's copies so a
## click on its row picks it again rather than a twin.
var pinned: PartData = null

var _rows: Dictionary = {}
var _list: VBoxContainer
var _empty_label: Label
var _sort_button: SortButton
var _tabs: Array[ScrapButton] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	refresh()

## Rebuilds the list from the stash: counts, order, which rows show.
func refresh() -> void:
	var loose_by_id := _loose_by_id()
	for id in _rows.keys():
		if not loose_by_id.has(id):
			_rows[id].visible = false
	var ids := loose_by_id.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return PartSort.comes_before(loose_by_id[a][0], loose_by_id[b][0], _sort_button.key))
	for id in ids:
		var copies: Array = loose_by_id[id]
		var slot: PartSlot = _rows.get(id)
		if slot == null:
			slot = _PART_SLOT_SCENE.instantiate()
			_list.add_child(slot)
			slot.category = copies[0].category
			slot.set_part(copies[0], copies.size())
			slot.gui_input.connect(_on_row_input.bind(id))
			_rows[id] = slot
		else:
			slot.set_count(copies.size())
		slot.visible = true
	for i in ids.size():
		_list.move_child(_rows[ids[i]], i)
	_empty_label.visible = ids.is_empty()
	_empty_label.text = EMPTY_HINTS[category]
	for i in _tabs.size():
		_tabs[i].selected = CATEGORIES[i] == category

## Forgets the row for `id` so it's rebuilt (with a fresh icon) next refresh.
func drop_row(id: StringName) -> void:
	var slot: PartSlot = _rows.get(id)
	if slot != null:
		slot.queue_free()
		_rows.erase(id)

func clear_rows() -> void:
	for slot in _rows.values():
		slot.queue_free()
	_rows.clear()

func show_category(value: PartData.Category) -> void:
	category = value
	refresh()

## Loose parts of the picked kind grouped as {id: [PartData, ...]}, the pinned
## copy first.
func _loose_by_id() -> Dictionary:
	var grouped := {}
	for part in Inventory.spare_parts:
		if part == null or part.category != category:
			continue
		if not grouped.has(part.id):
			grouped[part.id] = []
		if part == pinned:
			grouped[part.id].push_front(part)
		else:
			grouped[part.id].append(part)
	return grouped

func _on_row_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var copies: Array = _loose_by_id().get(id, [])
		if not copies.is_empty():
			part_picked.emit(copies[0])

func _build() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for i in CATEGORIES.size():
		var tab := ScrapButton.new()
		tab.text = TAB_NAMES[i]
		tab.font_size = 17
		tab.custom_minimum_size = Vector2(104, 42)
		tab.tilt_degrees = [-2.0, 1.5, -1.0, 2.0][i]
		tab.jitter_seed = seed_base + i
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(show_category.bind(CATEGORIES[i]))
		tabs.add_child(tab)
		_tabs.append(tab)
	var heading := _label(title, 16)
	heading.position = Vector2(2, 60)
	add_child(heading)
	_sort_button = SortButton.new()
	_sort_button.font_size = 15
	_sort_button.tilt_degrees = -1.0
	_sort_button.jitter_seed = seed_base + 4
	_sort_button.position = Vector2(270, 50)
	_sort_button.size = Vector2(170, 34)
	_sort_button.sort_changed.connect(func(_key: PartSort.Key) -> void: refresh())
	add_child(_sort_button)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, LIST_TOP)
	scroll.size = Vector2(size.x, size.y - LIST_TOP)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_empty_label = _label("", 18)
	_empty_label.position = Vector2(14, LIST_TOP + 22)
	add_child(_empty_label)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiPalette.TEXT_LIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
