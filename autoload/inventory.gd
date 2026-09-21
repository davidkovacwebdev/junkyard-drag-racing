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
## Cash, from selling scrap. The junkyard's crane charges for a grab, and this
## is what parts, repairs and race entry fees will draw on.
var money: int = 0
## Parts pulled out of the junkyard heap by the crane: owned, but not fitted to
## anything. Keeping them here (rather than only in the catalog) is what makes
## "what you grab is what you get" mean something.
var spare_parts: Array[PartData] = []

## Add to the scrap tally. Returns the new total.
func add_scrap(amount: int) -> int:
	scrap += amount
	return scrap

## Bank a part the crane fished out of the heap. Returns the stash size.
func add_part(part: PartData) -> int:
	if part != null:
		spare_parts.append(part)
	return spare_parts.size()

## Try to pay `amount`. False and no charge when the player can't afford it, so
## callers can turn the service down instead of putting them in debt.
func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false
	money -= amount
	return true

## Whether `amount` is covered, without spending anything. For callers that need
## to know *before* they commit to something they can't undo — the crane checks
## this up front so it doesn't sink its jaws into the heap and only then find out
## the player can't pay.
func can_afford(amount: int) -> bool:
	return amount <= 0 or money >= amount

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

## Wipe everything back to a fresh start: one car built from the worst
## (most basic) body/engine/wheel in the whole catalog, nothing else —
## no spare parts, no scrap, no cash. Called on boot and again by
## MainMenu's New Game, since SaveSystem's Continue only overwrites these
## fields rather than re-running _ready().
func reset() -> void:
	owned_cars.clear()
	selected_index = 0
	scrap = 0
	money = 0
	spare_parts.clear()
	owned_cars.append(_build_starter_car())

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

## "Worst" = tier 1 — the bottom quartile PartDatabase ranked this
## category into (see PartDatabase._assign_tiers()), which always
## includes at least the single lowest-scoring part for any non-empty
## category. Falls back to the first part on an empty/untiered array so
## this never returns null while the catalog has anything in it at all.
static func _worst(parts: Array) -> PartData:
	for part in parts:
		if part.tier == 1:
			return part
	return parts[0] if not parts.is_empty() else null
