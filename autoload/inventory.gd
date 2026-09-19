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

## The starter car the player already owns — always in slot 0.
const STARTER_BODY := "res://scenes/parts/bodies/body_classic.tscn"
const STARTER_ENGINE := "res://scenes/parts/engines/engine_v6.tscn"
const STARTER_WHEEL := "res://scenes/parts/wheels/wheel_standard.tscn"

func _ready() -> void:
	owned_cars.append(_build_car(STARTER_BODY, STARTER_ENGINE, STARTER_WHEEL))
	var pool: Array[BodyPartData] = []
	for body in PartDatabase.bodies:
		if body.id != &"body_classic":
			pool.append(body)
	pool.shuffle()
	for body in pool.slice(0, garage_capacity - 1):
		owned_cars.append(_build_random_car(body))

func get_selected_car() -> CarModelData:
	if owned_cars.is_empty():
		return null
	return owned_cars[clampi(selected_index, 0, owned_cars.size() - 1)]

func _build_car(body_path: String, engine_path: String, wheel_path: String) -> CarModelData:
	var car := CarModelData.new()
	car.body = PartDatabase.load_part_data(body_path) as BodyPartData
	car.engine = PartDatabase.load_part_data(engine_path) as EnginePartData
	var wheel := PartDatabase.load_part_data(wheel_path) as WheelPartData
	car.wheels = []
	car.wheels.append(wheel)
	car.wheels.append(wheel.duplicate())
	return car

func _build_random_car(body: BodyPartData) -> CarModelData:
	var car := CarModelData.new()
	car.body = body.duplicate() as BodyPartData
	car.engine = _random_engine().duplicate()
	var wheel := _random_wheel()
	var mount_count := PartDatabase.wheel_mount_count(car.body)
	car.wheels = []
	for i in mount_count:
		car.wheels.append(wheel.duplicate())
	return car

func _random_engine() -> EnginePartData:
	return PartDatabase.engines[randi() % PartDatabase.engines.size()]

func _random_wheel() -> WheelPartData:
	return PartDatabase.wheels[randi() % PartDatabase.wheels.size()]
