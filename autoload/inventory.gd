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
##
## OWNERSHIP, which is the part that used to be missing: the player owns a
## part if it's fitted to one of `owned_cars` or sitting loose in
## `spare_parts`, and every copy is a distinct Resource — never a shared
## PartDatabase catalog entry (see add_part). `fit_part()` is the only thing
## that moves a part between those places, and it moves rather than copies, so
## a part can't be fitted twice, one body can't be worn by two cars, and a
## swapped-out part can't silently vanish.

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
##
## The part is COPIED into the stash on purpose: both the crane (via
## TrashHeap.part_of) and the roadside part orbs hand over the PartData that
## hangs off a live heap item, which is the shared PartDatabase catalog entry
## itself. Storing that as-is would put the same Resource in the stash twice
## for two digs of the same wheel — one wheel the player owns two of, which
## `fit_part` could then only ever fit once.
func add_part(part: PartData) -> int:
	if part != null:
		stow_part(part.duplicate())
	return spare_parts.size()

## Park an already-owned part in the spare stash, as-is. For parts coming OFF a
## car (or back out of the catalog), which are already the player's own
## instance — see add_part for the copy-on-pickup case.
func stow_part(part: PartData) -> void:
	if part != null:
		spare_parts.append(part)

## Pull one stashed copy of the part that lives in `scene_path` out of the
## stash, or null when the player has none. For filling a slot with a specific
## part without minting a new one — see _default_wheel.
func take_stashed(scene_path: String) -> PartData:
	for i in spare_parts.size():
		var part := spare_parts[i]
		if part != null and part.scene_path == scene_path:
			spare_parts.remove_at(i)
			return part
	return null

## How many copies of `part` the player owns, fitted or loose. Matched by id,
## since copies of the same part are interchangeable — only the count matters.
func owned_count(part: PartData) -> int:
	if part == null:
		return 0
	var count := 0
	for loose in spare_parts:
		if loose != null and loose.id == part.id:
			count += 1
	for car in owned_cars:
		count += _fitted_count(car, part)
	return count

## Whether the player owns at least one copy of `part`.
func owns_part(part: PartData) -> bool:
	return owned_count(part) > 0

## Take ONE owned copy of `part` (by id) out of wherever it lives — the spare
## stash first, then any car's fitted slots — and report where it came from.
## Nothing is lost or cloned: the copy leaves its slot empty and comes back in
## `PartHome.part`, for the caller to fit somewhere or hand back with
## `give_part()`. Null when the player owns no copy to begin with.
func detach_part(part: PartData) -> PartHome:
	if part == null:
		return null
	for i in spare_parts.size():
		var loose := spare_parts[i]
		if loose != null and loose.id == part.id:
			spare_parts.remove_at(i)
			return _home(loose, null, PartHome.SLOT_SPARE)
	for car in owned_cars:
		var home := _detach_fitted(car, part)
		if home != null:
			return home
	return null

## Put `part` back where a `detach_part()` took its copy from: the car slot it
## was yanked out of, or the spare stash. This is what makes an equip a swap —
## the part leaving a slot lands exactly where the incoming one came from, so
## borrowing another car's body hands it that car's old body in return and
## neither car is ever left incomplete.
##
## A slot of the wrong kind for the part (only reachable from a hand-built
## PartHome) falls through to the stash: there is always a valid home there,
## and silently writing a null into a slot would lose a part.
func give_part(home: PartHome, part: PartData) -> void:
	if part == null:
		return
	if home != null and home.car != null:
		match home.slot:
			PartHome.SLOT_BODY:
				if part is BodyPartData:
					home.car.body = part as BodyPartData
					return
			PartHome.SLOT_ENGINE:
				if part is EnginePartData:
					home.car.engine = part as EnginePartData
					return
			_:
				if part is WheelPartData and home.slot >= 0 \
						and home.slot < home.car.wheels.size():
					home.car.wheels[home.slot] = part as WheelPartData
					return
	stow_part(part)

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

# --- Fitting (the ownership rules) ---------------------------------------------

## The tire an empty wheel mount gets. Same scene the starter car rolls on.
const DEFAULT_WHEEL := "res://scenes/parts/wheels/wheel_standard.tscn"

## Fit `part` to `car`, MOVING one owned copy rather than cloning one, and
## swapping whatever was in the slot back to wherever that copy came from.
##
## The single place the ownership rules are enforced, so:
##   - a part can't be fitted twice — there is only ever one copy to fit;
##   - the same body/wheel can't be worn by two cars at once — borrowing
##     another car's part swaps the two over, leaving both cars complete;
##   - a swapped-out part is never lost: it lands in the stash, or in the slot
##     the incoming copy just vacated.
##
## `wheel_index` >= 0 is the mount a wheel was dropped on; -1 picks the first
## mount not already wearing that same wheel. Returns false, having touched
## nothing, when the player doesn't own a copy to fit.
func fit_part(car: CarModelData, category: PartData.Category, part: PartData,
		wheel_index: int = -1) -> bool:
	if car == null or part == null:
		return false
	match category:
		PartData.Category.BODY:
			return _fit_body(car, part)
		PartData.Category.ENGINE:
			return _fit_engine(car, part)
		PartData.Category.WHEEL:
			return _fit_wheel(car, part, wheel_index)
	return false

## Put `body_part` on `car`. The car can never end up bodiless: the displaced
## body goes back where the new one came from, so taking another car's body is
## a straight swap of the two cars' bodies rather than a clone that strips the
## other car.
##
## What lands in the slot is the very copy `detach_part` pulled out of the
## pool — moved, not cloned — so there is no second copy for another car to
## wear and no orphaned instance left behind.
func _fit_body(car: CarModelData, body_part: PartData) -> bool:
	var displaced: PartData = car.body
	var home := detach_part(body_part)
	if home == null:
		return false
	# Order matters: the displaced body is written back where the new one came
	# from, which may be this very slot (re-fitting the body it already wears),
	# so claim the slot only after that write. Both cars then get their wheels
	# re-cut to the body they now wear.
	give_part(home, displaced)
	car.body = home.part as BodyPartData
	if home.car != null and home.car != car:
		_fit_wheels_to_body(home.car)
	_fit_wheels_to_body(car)
	return true

## Put `engine_part` on `car` — same swap rule as the body, minus the wheel
## bookkeeping (an engine doesn't change how many mounts a car has).
func _fit_engine(car: CarModelData, engine_part: PartData) -> bool:
	var displaced: PartData = car.engine
	var home := detach_part(engine_part)
	if home == null:
		return false
	give_part(home, displaced)
	car.engine = home.part as EnginePartData
	return true

## Bolt `wheel_part` onto `car`. `mount` >= 0 is the mount a wheel was dropped
## on; -1 (a whole-car drop) sends it to the first mount not already wearing
## that same wheel, so ONE drop fits ONE mount. Stamping a single tire across
## every mount is what made "the same wheel on all four corners" look legal —
## with a real pool, four mounts take four owned tires.
##
## The copy comes out of the pool BEFORE the mount is picked and before
## anything is filled in, because detaching is the step that can fail: filling
## a mount first and only then discovering the player owns no such wheel would
## mint (or worse, take a spare) for a drop that never happened.
func _fit_wheel(car: CarModelData, wheel_part: PartData, mount: int) -> bool:
	var mount_count := PartDatabase.wheel_mount_count(car.body)
	if mount_count <= 0:
		return false
	var home := detach_part(wheel_part)
	if home == null:
		return false
	# Grown, never filled: an empty mount stays empty unless this drop is
	# putting a wheel in it, and the address has to exist before it can be
	# written to.
	if car.wheels.size() < mount_count:
		car.wheels.resize(mount_count)
	var target := mount
	if target < 0 or target >= mount_count:
		target = _open_mount_for(car, wheel_part, mount_count)
	var displaced: PartData = car.wheels[target]
	give_part(home, displaced)
	car.wheels[target] = home.part as WheelPartData
	return true

## Which mount a whole-car wheel drop lands on: the first that isn't already
## wearing this same wheel. With every mount already on it, mount 0 — so the
## drop reads as "already fitted" instead of quietly cloning the tire.
func _open_mount_for(car: CarModelData, wheel: PartData, mount_count: int) -> int:
	for i in mini(mount_count, car.wheels.size()):
		var fitted: PartData = car.wheels[i]
		if fitted == null or fitted.id != wheel.id:
			return i
	return 0

## Cut a car's wheels up (or down) to the mount count of the body it's wearing.
## Surplus wheels are NOT deleted — the player still owns them, so they go back
## to the stash; otherwise pairing a small body with a big one would silently
## eat real parts. Growth fills the new mounts (see _default_wheel) so a car is
## never left undrivable.
func _fit_wheels_to_body(car: CarModelData) -> void:
	if car == null or car.body == null:
		return
	var mount_count := PartDatabase.wheel_mount_count(car.body)
	_ensure_wheel_count(car, mount_count)
	while car.wheels.size() > mount_count:
		var surplus: PartData = car.wheels.pop_back()
		stow_part(surplus)

## Make sure every mount up to `count` has a wheel in it, filling the empty
## ones with the basic tire. Only ever called when the body has just changed
## (see _fit_wheels_to_body) — a wheel the player drops in is fitted by
## _fit_wheel, which leaves the other mounts alone rather than minting.
func _ensure_wheel_count(car: CarModelData, count: int) -> void:
	if car.wheels.size() < count:
		car.wheels.resize(count)
	for i in count:
		if car.wheels[i] == null:
			car.wheels[i] = _default_wheel()

## The tire an empty mount gets: a standard wheel out of the player's stash if
## they have one going spare — a bigger body should draw on the pile rather
## than mint wheels, or swapping bodies back and forth would print them —
## otherwise a fresh basic tire so the car stays drivable.
##
## The fresh one is duplicated off the catalog entry rather than handed out as
## itself: load_part_data() reads a PartData straight out of a part scene, so
## every call returns the SAME Resource, and two mounts filled with "a standard
## wheel" would be two mounts wearing one wheel (see add_part for the same rule
## at pickup time).
func _default_wheel() -> WheelPartData:
	var stashed := take_stashed(DEFAULT_WHEEL) as WheelPartData
	if stashed != null:
		return stashed
	for wheel in PartDatabase.wheels:
		if wheel.scene_path == DEFAULT_WHEEL:
			return wheel.duplicate() as WheelPartData
	return null

## One car's fitted copies of `part` (by id).
func _fitted_count(car: CarModelData, part: PartData) -> int:
	if car == null:
		return 0
	var count := 0
	if car.body != null and car.body.id == part.id:
		count += 1
	if car.engine != null and car.engine.id == part.id:
		count += 1
	for wheel in car.wheels:
		if wheel != null and wheel.id == part.id:
			count += 1
	return count

## Take one copy of `part` out of `car`'s fitted slots, clearing whichever slot
## it came from.
func _detach_fitted(car: CarModelData, part: PartData) -> PartHome:
	if car == null:
		return null
	if car.body != null and car.body.id == part.id:
		var body := car.body
		car.body = null
		return _home(body, car, PartHome.SLOT_BODY)
	if car.engine != null and car.engine.id == part.id:
		var engine := car.engine
		car.engine = null
		return _home(engine, car, PartHome.SLOT_ENGINE)
	for i in car.wheels.size():
		var wheel := car.wheels[i]
		if wheel != null and wheel.id == part.id:
			car.wheels[i] = null
			return _home(wheel, car, i)
	return null

static func _home(part: PartData, car: CarModelData, slot: int) -> PartHome:
	var home := PartHome.new()
	home.part = part
	home.car = car
	home.slot = slot
	return home
