class_name Garage
extends Control
## Placeholder garage screen: browse the player's owned cars with the
## prev/next arrows. Fixed pixel layout for now, not responsive — fine
## for a single early-game screen.

@onready var _car_visual: CarVisual = $CarPreview
@onready var _name_label: Label = $NameLabel
@onready var _parts_list: VBoxContainer = $PartsScroll/PartsList
@onready var _body_filter_button: Button = $BodyFilterButton
@onready var _engine_filter_button: Button = $EngineFilterButton
@onready var _wheel_filter_button: Button = $WheelFilterButton
@onready var _body_slot: PartSlot = $BodySlot
@onready var _engine_slot: PartSlot = $EngineSlot
@onready var _wheel_slot: PartSlot = $WheelSlot
@onready var _car_drop_zone: CarDropZone = $CarDropZone

var _index: int = 0
var _escape_pressed_last: bool = false

const _INACTIVE_FILTER_COLOR := Color(0.85, 0.85, 0.85, 1)
const _ACTIVE_FILTER_COLOR := Color(1, 0.8, 0.2, 1)
const _PART_SLOT_SCENE := preload("res://scenes/garage/part_slot.tscn")

func _ready() -> void:
	_body_slot.category = PartData.Category.BODY
	_body_slot.garage = self
	_engine_slot.category = PartData.Category.ENGINE
	_engine_slot.garage = self
	_wheel_slot.category = PartData.Category.WHEEL
	_wheel_slot.garage = self
	_car_drop_zone.garage = self

	_index = clampi(Inventory.selected_index, 0, maxi(Inventory.owned_cars.size() - 1, 0))
	_refresh()
	_show_category(PartData.Category.BODY)

func _process(_delta: float) -> void:
	var escape_pressed := Input.is_physical_key_pressed(KEY_ESCAPE)
	if escape_pressed and not _escape_pressed_last:
		get_tree().change_scene_to_file("res://scenes/world/main.tscn")
	_escape_pressed_last = escape_pressed

func _on_prev_pressed() -> void:
	_cycle(-1)

func _on_next_pressed() -> void:
	_cycle(1)

func _cycle(step: int) -> void:
	var count := Inventory.owned_cars.size()
	if count == 0:
		return
	_index = (_index + step + count) % count
	Inventory.selected_index = _index
	_refresh()

func _refresh() -> void:
	var cars := Inventory.owned_cars
	if cars.is_empty():
		_name_label.text = "No cars in the garage yet"
		_car_visual.visible = false
		return
	_car_visual.visible = true
	var car: CarModelData = cars[_index]
	_car_visual.set_body_color(car.body_color)
	_name_label.text = "%s  (%d/%d)" % [car.display_name, _index + 1, cars.size()]
	_body_slot.set_part(car.body)
	_engine_slot.set_part(car.engine)
	_wheel_slot.set_part(car.wheels[0] if not car.wheels.is_empty() else null)

## Called by any PartSlot (catalog row or the car's own equipped-part
## slot) when a matching-category part gets dropped on it. Always
## applies to the currently-viewed car, regardless of which slot
## actually received the drop.
func equip_part(category: PartData.Category, part: PartData) -> void:
	var cars := Inventory.owned_cars
	if cars.is_empty():
		return
	var car: CarModelData = cars[_index]
	match category:
		PartData.Category.BODY:
			car.body = part.duplicate() as BodyPartData
		PartData.Category.ENGINE:
			car.engine = part.duplicate() as EnginePartData
		PartData.Category.WHEEL:
			var wheel := part.duplicate() as WheelPartData
			car.wheels = [wheel, wheel.duplicate()]
	_refresh()

func _on_body_filter_pressed() -> void:
	_show_category(PartData.Category.BODY)

func _on_engine_filter_pressed() -> void:
	_show_category(PartData.Category.ENGINE)

func _on_wheel_filter_pressed() -> void:
	_show_category(PartData.Category.WHEEL)

func _show_category(category: PartData.Category) -> void:
	for child in _parts_list.get_children():
		child.queue_free()

	var parts: Array = []
	match category:
		PartData.Category.BODY:
			parts = PartDatabase.bodies
		PartData.Category.ENGINE:
			parts = PartDatabase.engines
		PartData.Category.WHEEL:
			parts = PartDatabase.wheels

	for part in parts:
		var slot: PartSlot = _PART_SLOT_SCENE.instantiate()
		# Add before set_part(): PartIcon's @onready SubViewport ref only
		# resolves once it's actually inside the live tree, which
		# add_child() does synchronously for a parent that's already there.
		_parts_list.add_child(slot)
		slot.category = category
		slot.garage = self
		slot.set_part(part)

	_body_filter_button.add_theme_color_override("font_color", _ACTIVE_FILTER_COLOR if category == PartData.Category.BODY else _INACTIVE_FILTER_COLOR)
	_engine_filter_button.add_theme_color_override("font_color", _ACTIVE_FILTER_COLOR if category == PartData.Category.ENGINE else _INACTIVE_FILTER_COLOR)
	_wheel_filter_button.add_theme_color_override("font_color", _ACTIVE_FILTER_COLOR if category == PartData.Category.WHEEL else _INACTIVE_FILTER_COLOR)
