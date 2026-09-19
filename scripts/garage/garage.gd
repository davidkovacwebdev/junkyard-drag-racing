class_name Garage
extends Control
## Garage screen: browse owned cars, then drag parts straight onto the
## car itself — bodies drop anywhere on the car, engines drop on the car,
## and wheels drop onto the individual wheel mounts (which light up while
## you drag a wheel). The preview IS the car: it's assembled from the
## selected car's real part scenes, so what you see here is exactly what
## you drive in the world.

@onready var _car_view: CarView = $CarPreview
@onready var _name_label: Label = $NameLabel
@onready var _parts_list: VBoxContainer = $PartsScroll/PartsList
@onready var _body_filter_button: Button = $BodyFilterButton
@onready var _engine_filter_button: Button = $EngineFilterButton
@onready var _wheel_filter_button: Button = $WheelFilterButton
@onready var _car_drop_zone: CarDropZone = $CarDropZone

var _index: int = 0
var _escape_pressed_last: bool = false
var _wheel_mount_zones: Array[WheelMountZone] = []

const _INACTIVE_FILTER_COLOR := Color(0.85, 0.85, 0.85, 1)
const _ACTIVE_FILTER_COLOR := Color(1, 0.8, 0.2, 1)
const _PART_SLOT_SCENE := preload("res://scenes/garage/part_slot.tscn")
const _WHEEL_MOUNT_ZONE_SCENE := preload("res://scenes/garage/wheel_mount_zone.tscn")
const _DEFAULT_WHEEL := "res://scenes/parts/wheels/wheel_standard.tscn"

func _ready() -> void:
	_car_drop_zone.garage = self
	_index = clampi(Inventory.selected_index, 0, maxi(Inventory.owned_cars.size() - 1, 0))
	_refresh()
	_show_category(PartData.Category.BODY)

func _process(_delta: float) -> void:
	var escape_pressed := Input.is_physical_key_pressed(KEY_ESCAPE)
	if escape_pressed and not _escape_pressed_last:
		get_tree().change_scene_to_file("res://scenes/world/main.tscn")
	_escape_pressed_last = escape_pressed

	# While dragging a catalog part, light up the valid drop spots on the
	# car (wheel mounts, engine bay, or the whole body) based on category.
	# get_viewport() returns null while the scene is being torn down right
	# after change_scene_to_file(), so guard it before reading drag data.
	var viewport := get_viewport()
	if viewport == null:
		return
	var drag: Variant = viewport.gui_get_drag_data()
	if typeof(drag) == TYPE_DICTIONARY and drag.has("category"):
		_car_view.set_highlight(int(drag["category"]))
	else:
		_car_view.set_highlight(-1)

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
		_car_view.visible = false
		_clear_wheel_mount_zones()
		return
	_car_view.visible = true
	var car: CarModelData = cars[_index]
	_car_view.build_from(car)
	_name_label.text = "%s  (%d/%d)" % [car.display_name, _index + 1, cars.size()]
	_rebuild_wheel_mount_zones()

func _rebuild_wheel_mount_zones() -> void:
	_clear_wheel_mount_zones()
	for mount in _car_view.get_wheel_mounts():
		var zone: WheelMountZone = _WHEEL_MOUNT_ZONE_SCENE.instantiate()
		zone.garage = self
		zone.wheel_index = _wheel_mount_zones.size()
		add_child(zone)
		_wheel_mount_zones.append(zone)
		zone.global_position = _car_view.to_global(mount) - zone.size / 2.0

func _clear_wheel_mount_zones() -> void:
	for zone in _wheel_mount_zones:
		zone.queue_free()
	_wheel_mount_zones.clear()

## Called by a drop zone when a part lands. `wheel_index` >= 0 means a
## wheel dropped on that specific mount; -1 (whole-car drops) applies the
## wheel to every mount, or the single body/engine for those categories.
func equip_part(category: PartData.Category, part: PartData, wheel_index: int = -1) -> void:
	var cars := Inventory.owned_cars
	if cars.is_empty():
		return
	var car: CarModelData = cars[_index]
	match category:
		PartData.Category.BODY:
			car.body = part.duplicate() as BodyPartData
			_resize_wheels(car)
		PartData.Category.ENGINE:
			car.engine = part.duplicate() as EnginePartData
		PartData.Category.WHEEL:
			var wheel := part.duplicate() as WheelPartData
			var mount_count := PartDatabase.wheel_mount_count(car.body)
			_ensure_wheel_count(car, mount_count)
			if wheel_index >= 0 and wheel_index < mount_count:
				car.wheels[wheel_index] = wheel
			else:
				for i in mount_count:
					car.wheels[i] = wheel.duplicate()
	_refresh()

func _resize_wheels(car: CarModelData) -> void:
	var mount_count := PartDatabase.wheel_mount_count(car.body)
	_ensure_wheel_count(car, mount_count)
	car.wheels.resize(mount_count)

func _ensure_wheel_count(car: CarModelData, count: int) -> void:
	while car.wheels.size() < count:
		car.wheels.append(_default_wheel())

func _default_wheel() -> WheelPartData:
	return PartDatabase.load_part_data(_DEFAULT_WHEEL) as WheelPartData

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
