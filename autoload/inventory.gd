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
## Save/load lives in SaveSystem, which reads/writes these fields
## directly — they're already just Resources + ints, exactly so that
## could happen without restructuring anything here.

var garage_capacity: int = 2
var owned_cars: Array[CarModelData] = []
var selected_index: int = 0
## Loose trash hauled out of roadside bins. Sold to the scrap dealer at the
## junkyard for cash; until you sell it, it's just weight in the trunk.
var scrap: int = 0
## Cash. Only the scrap dealer puts money in here so far, and nothing spends it
## yet — but this is what parts, repairs and race entry fees will draw on.
var money: int = 0

## Add to the scrap tally. Returns the new total.
func add_scrap(amount: int) -> int:
	scrap += amount
	return scrap

## Sell the whole scrap pile at `rate` cash per scrap. Empties `scrap`, banks
## the cash, and returns what was earned so the caller can show it.
func sell_scrap(rate: int = 1) -> int:
	if scrap <= 0:
		return 0
	var earned := scrap * rate
	scrap = 0
	money += earned
	return earned

func _ready() -> void:
	reset()

## Wipe everything back to a fresh start: the worst-stats starter car,
## a random pair to fill out the rest of the garage, and empty pockets.
## Called on boot and again by MainMenu's New Game, since SaveSystem's
## Continue only overwrites these fields rather than re-running _ready().
func reset() -> void:
	owned_cars.clear()
	selected_index = 0
	scrap = 0
	money = 0

	var starter := _build_starter_car()
	owned_cars.append(starter)
	var pool: Array[BodyPartData] = []
	for body in PartDatabase.bodies:
		if body.id != starter.body.id:
			pool.append(body)
	pool.shuffle()
	for body in pool.slice(0, garage_capacity - 1):
		owned_cars.append(_build_random_car(body))

func get_selected_car() -> CarModelData:
	if owned_cars.is_empty():
		return null
	return owned_cars[clampi(selected_index, 0, owned_cars.size() - 1)]

## You start in a junkyard, so you start in a heap — the worst body,
## engine and wheel in the whole catalog, not a random one.
func _build_starter_car() -> CarModelData:
	var body := _worst(PartDatabase.bodies) as BodyPartData
	var engine := _worst(PartDatabase.engines) as EnginePartData
	var wheel := _worst(PartDatabase.wheels) as WheelPartData
	var car := CarModelData.new()
	car.body = body.duplicate() as BodyPartData
	car.engine = engine.duplicate() as EnginePartData
	var mount_count := PartDatabase.wheel_mount_count(car.body)
	car.wheels = []
	for i in mount_count:
		car.wheels.append(wheel.duplicate())
	return car

## "Worst" = lowest durability + speed (the two catalog stats with an
## obvious better/worse direction). Mass isn't weighted either way —
## heavier isn't inherently worse, just heavier.
static func _worst(parts: Array) -> PartData:
	var worst: PartData = null
	var worst_score := INF
	for part in parts:
		var score: float = part.durability + part.speed
		if score < worst_score:
			worst_score = score
			worst = part
	return worst

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
