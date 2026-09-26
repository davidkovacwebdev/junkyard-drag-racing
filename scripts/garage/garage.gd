class_name Garage
extends Control
## Garage screen: browse owned cars, then drag parts straight onto the
## car itself — bodies drop anywhere on the car, engines drop on the car,
## and wheels drop onto the individual wheel mounts (which light up while
## you drag a wheel). The preview IS the car: it's assembled from the
## selected car's real part scenes, so what you see here is exactly what
## you drive in the world.

@onready var _car_view: CarView = $CarPreview
@onready var _name_label: Label = $NamePlate/NameLabel
@onready var _parts_list: GridContainer = $PartsScroll/PartsList
@onready var _parts_empty_label: Label = $PartsEmptyLabel
@onready var _body_filter_button: ScrapButton = $BodyFilterButton
@onready var _engine_filter_button: ScrapButton = $EngineFilterButton
@onready var _wheel_filter_button: ScrapButton = $WheelFilterButton
@onready var _car_drop_zone: CarDropZone = $CarDropZone

var _index: int = 0
var _wheel_mount_zones: Array[WheelMountZone] = []
var _current_category: PartData.Category = PartData.Category.BODY

const _PART_SLOT_SCENE := preload("res://scenes/garage/part_slot.tscn")
const _WHEEL_MOUNT_ZONE_SCENE := preload("res://scenes/garage/wheel_mount_zone.tscn")

## Shown in place of the part rows when a tab has nothing to offer, so an empty
## list reads as "you have no spares" rather than "the garage is broken".
const _EMPTY_HINTS := {
	PartData.Category.BODY: "No spare car bodies.\nDig one up at the junkyard.",
	PartData.Category.ENGINE: "No spare engines.\nDig one up at the junkyard.",
	PartData.Category.WHEEL: "No spare wheels.\nDig some up at the junkyard.",
}

func _ready() -> void:
	_car_drop_zone.garage = self
	_index = clampi(Inventory.selected_index, 0, maxi(Inventory.owned_cars.size() - 1, 0))
	_refresh()
	_show_category(PartData.Category.BODY)

func _process(_delta: float) -> void:
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

## Called by a drop zone when a part lands. `wheel_index` >= 0 means a wheel
## dropped on that specific mount; -1 (a whole-car drop) sends it to the first
## mount not already wearing it.
##
## The fit itself is Inventory.fit_part, which MOVES an owned copy rather than
## cloning one — so the same tire can't be bolted on twice, one body can't end
## up on two cars, and whatever gets swapped out is never lost. All this does
## is charge the time, then rebuild the view.
func equip_part(category: PartData.Category, part: PartData, wheel_index: int = -1) -> void:
	var car := _selected_car()
	if car == null or not Inventory.fit_part(car, category, part, wheel_index):
		return
	# A wheel swap is a minute's work; a body or an engine is most of a day.
	DayNightCycle.advance_hours(1.0 if category == PartData.Category.WHEEL else 4.0)
	Sfx.play(&"wrench_clunk", -4.0)
	_refresh()
	# Ownership changed — a copy moved out of the stash onto the car, or
	# between two cars — so the list has to be rebuilt with fresh counts
	# rather than left showing whatever was true a moment ago.
	_show_category(_current_category)

## The car the garage is showing, and the one PlayerCar drives in the world.
func _selected_car() -> CarModelData:
	if Inventory.owned_cars.is_empty():
		return null
	return Inventory.owned_cars[_index]

## Parts the player can fit to the car being viewed: everything they own
## EXCEPT what that car is already wearing — a part bolted to this car is on
## the car, not in the parts list, and re-fitting it would only charge the
## clock for a no-op. That means a car on its own (a fresh game) lists
## nothing, which is correct: the starter body/engine/wheels live on the car.
##
## Everything else stays pickable, because parts are owned, not per-car: what
## another car wears can be borrowed (fitting swaps the two over), and anything
## loose in the spare-parts stash from a crane dig is fair game.
## PartDatabase.bodies/wheels/engines (the full catalog) is never shown
## outright — this isn't a shop, everything has to be earned at the
## junkyard first.
##
## One row per part id, with how many copies are AVAILABLE to fit here. The
## count is the whole point of the row now that fitting moves a copy instead
## of cloning it: four identical tires and one tire look the same on the
## icon, but only the first can fill four mounts, and a copy already on this
## car can't fill another one. Rows are `{"part": PartData, "count": int}`.
func _owned_parts(category: PartData.Category) -> Array[Dictionary]:
	var viewed := _selected_car()
	var owned: Dictionary = {}
	var counts: Dictionary = {}
	for car in Inventory.owned_cars:
		# The viewed car's own parts are what it's wearing, not spares.
		if car == viewed:
			continue
		match category:
			PartData.Category.BODY:
				_tally_owned(owned, counts, car.body)
			PartData.Category.ENGINE:
				_tally_owned(owned, counts, car.engine)
			PartData.Category.WHEEL:
				for wheel in car.wheels:
					_tally_owned(owned, counts, wheel)
	for part in Inventory.spare_parts:
		if part != null and part.category == category:
			_tally_owned(owned, counts, part)
	var rows: Array[Dictionary] = []
	for id in owned:
		rows.append({"part": owned[id], "count": counts[id]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: PartData = a["part"]
		var right: PartData = b["part"]
		return left.display_name < right.display_name
	)
	return rows

## Add one copy of `part` to the running tally, keyed by id — the same part
## found twice (once fitted, once loose in the stash) is one row that knows
## it's owned twice, not two identical rows.
static func _tally_owned(owned: Dictionary, counts: Dictionary, part: PartData) -> void:
	if part == null:
		return
	if owned.has(part.id):
		counts[part.id] = int(counts[part.id]) + 1
		return
	owned[part.id] = part
	counts[part.id] = 1

func _on_body_filter_pressed() -> void:
	_show_category(PartData.Category.BODY)

func _on_engine_filter_pressed() -> void:
	_show_category(PartData.Category.ENGINE)

func _on_wheel_filter_pressed() -> void:
	_show_category(PartData.Category.WHEEL)

func _show_category(category: PartData.Category) -> void:
	_current_category = category
	for child in _parts_list.get_children():
		child.queue_free()

	var rows := _owned_parts(category)
	_parts_empty_label.visible = rows.is_empty()
	_parts_empty_label.text = _EMPTY_HINTS[category] if rows.is_empty() else ""
	for row in rows:
		var slot: PartSlot = _PART_SLOT_SCENE.instantiate()
		# Add before set_part(): PartIcon's @onready SubViewport ref only
		# resolves once it's actually inside the live tree, which
		# add_child() does synchronously for a parent that's already there.
		_parts_list.add_child(slot)
		slot.category = category
		slot.garage = self
		slot.set_part(row["part"], row["count"])

	_body_filter_button.selected = category == PartData.Category.BODY
	_engine_filter_button.selected = category == PartData.Category.ENGINE
	_wheel_filter_button.selected = category == PartData.Category.WHEEL
