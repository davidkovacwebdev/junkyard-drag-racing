extends Node
## Placeholder player inventory (autoload singleton "Inventory"). Holds
## which cars the player owns, how many the garage can currently hold,
## and which one is selected — that's the one PlayerCar drives with in
## the open world.
##
## Cars are built from real parts (BodyPartData/EnginePartData/
## WheelPartData, the same classes the drag-race rig uses) rather than a
## one-off car struct, so equipping different parts is just swapping
## entries in a CarModelData's .engine/.wheels — no new plumbing needed
## when a garage customization UI shows up.
##
## No save/load yet — that's planned, not built. When it lands, this
## state (owned_cars, garage_capacity, selected_index) is already just
## Resources + ints, so it can go straight to ResourceSaver/JSON.

var garage_capacity: int = 2
var owned_cars: Array[CarModelData] = []
var selected_index: int = 0

## The car the player already had and liked before this system existed —
## always owned, always in slot 0, never part of the random draw.
const _STARTER_CAR := {"id": &"bumper_special", "name": "Bumper Special", "color": Color(0.6, 0.15, 0.15)}

## Extra bodies that can fill the garage's other, random slots.
const _RANDOM_BODY_POOL := [
	{"id": &"rustbucket", "name": "Rustbucket", "color": Color(0.55, 0.32, 0.18)},
	{"id": &"blue_streak", "name": "Blue Streak", "color": Color(0.2, 0.35, 0.6)},
	{"id": &"junker", "name": "Junker", "color": Color(0.35, 0.4, 0.28)},
	{"id": &"sunburst", "name": "Sunburst", "color": Color(0.75, 0.55, 0.15)},
]

func _ready() -> void:
	owned_cars.append(_build_car(_STARTER_CAR))
	var pool := _RANDOM_BODY_POOL.duplicate()
	pool.shuffle()
	for entry in pool.slice(0, garage_capacity - 1):
		owned_cars.append(_build_car(entry))

func get_selected_car() -> CarModelData:
	if owned_cars.is_empty():
		return null
	return owned_cars[clampi(selected_index, 0, owned_cars.size() - 1)]

func _build_car(entry: Dictionary) -> CarModelData:
	var body := BodyPartData.new()
	body.id = entry["id"]
	body.display_name = entry["name"]
	body.color = entry["color"]

	body.default_engine = EnginePartData.new()
	body.default_engine.id = StringName("%s_engine" % entry["id"])
	body.default_engine.display_name = "%s Engine" % entry["name"]

	var car := CarModelData.new()
	car.body = body
	car.engine = body.default_engine
	car.wheels = [_make_standard_wheel(), _make_standard_wheel()]
	return car

func _make_standard_wheel() -> WheelPartData:
	var wheel := WheelPartData.new()
	wheel.id = &"standard_wheel"
	wheel.display_name = "Standard Wheel"
	return wheel
