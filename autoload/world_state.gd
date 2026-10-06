extends Node
## Remembers where the player was standing on the world map, so leaving a
## place (garage, drag strip race, ...) drops them back at the same spot
## instead of at the map origin.
##
## The PlayerCar writes its position here every physics frame and reads it
## back on spawn. Kept as an autoload rather than a static var so the value
## survives `change_scene_to_*` calls without anything having to pass it
## along — every place's exit path just reloads main.tscn and this does the
## rest.
##
## It also remembers the state of the city's roadside trash, which is the other
## thing that has to outlive a map reload: which bins are empty, and which have
## come back. The city starts mostly picked-over, and every emptied prop
## refills in one pass each morning, sometime between 8 and 9 AM — see
## `is_prop_full()` and `restocked`.

## Last known player position in world (map) coordinates.
var player_position: Vector2 = Vector2.ZERO
## False until the player has been on the map at least once. Without this
## the first load would snap the player to the origin, which happens to be
## correct here but is not something to rely on.
var has_player_position: bool = false
## The world camera's zoom, so stepping into the shop (or any other place)
## and back out doesn't reset it. 0 until the player first zooms.
var camera_zoom: float = 0.0

## Props the player has emptied, and the in-game day each was emptied on. An id
## in here is empty right now; an id that isn't is full. See `is_prop_full()`.
var _empty_since: Dictionary = {}
## Ids a daily restock has put back. Without this record a refilled prop would
## fall back to its "started empty" roll and quietly empty itself again the next
## time the map reloaded.
var _refilled: Dictionary = {}
## The day `_restock_hour` was rolled for. Once `_restocked_today` is true for
## this day, nothing restocks again until the day changes.
var _restock_plan_day: int = 0
## Today's restock moment, rolled fresh each day so the whole city doesn't
## refill at the exact same instant every morning.
var _restock_hour: float = RESTOCK_WINDOW_START
var _restocked_today: bool = false
## Times Hank's tow truck has pulled the car out of the sea. From the third,
## he hands over his fishing rod (TowTruckRescueCutscene).
var tow_count: int = 0
## One-off finds the player has taken (the hangar's saucer). Unlike bins these
## never come back.
var _claimed: Dictionary = {}

## Chance a prop is full the first time the world is ever generated. Kept low on
## purpose: the city starts mostly picked-over, so finding a full bin is worth a
## detour rather than being the default state.
const INITIAL_FULL_CHANCE := 0.2
## Every emptied prop refills in one pass sometime in this window each
## morning — a spread rather than a fixed instant, so the whole city doesn't
## visibly snap full at once.
const RESTOCK_WINDOW_START := 8.0
const RESTOCK_WINDOW_END := 9.0

## Fired the moment a daily restock actually happens, so any TrashProp already
## sitting in the loaded scene can refresh itself live instead of only picking
## up the change the next time the map reloads.
signal restocked

func _process(_delta: float) -> void:
	_check_restock()

func remember_player(position: Vector2) -> void:
	player_position = position
	has_player_position = true

## Whether `id` is full — i.e. worth opening — right now. Every caller wants a
## current answer, so this is also where the daily restock gets advanced.
func is_prop_full(id: String) -> bool:
	if id.is_empty():
		return true
	_check_restock()
	if _empty_since.has(id):
		return false
	if _refilled.has(id):
		return true
	# Never seen before in this save: this is its very first state, rolled
	# stably from the id so the same prop starts the same way on every reload.
	return _starts_full(id)

## Record that a prop was emptied on the current day. It comes back the next
## time the morning restock window passes.
func mark_emptied(id: String) -> void:
	if id.is_empty():
		return
	_check_restock()
	_refilled.erase(id)
	_empty_since[id] = DayNightCycle.day

func is_claimed(id: String) -> bool:
	return _claimed.has(id)

func mark_claimed(id: String) -> void:
	_claimed[id] = DayNightCycle.day

func unclaim(id: String) -> void:
	_claimed.erase(id)

## How many props are empty right now.
func looted_count() -> int:
	return _empty_since.size()

## Snapshot of the restock state, for SaveSystem to write out.
func get_looted_snapshot() -> Dictionary:
	_check_restock()
	return {
		"empty": _empty_since.duplicate(),
		"refilled": _refilled.duplicate(),
		"restock_plan_day": _restock_plan_day,
		"restock_hour": _restock_hour,
		"restocked_today": _restocked_today,
		"claimed": _claimed.duplicate(),
	}

## Restore a previously-saved snapshot (SaveSystem on Continue).
func restore_looted(snapshot: Dictionary) -> void:
	_empty_since.clear()
	_refilled.clear()
	_restock_plan_day = 0
	_restock_hour = RESTOCK_WINDOW_START
	_restocked_today = false
	_claimed.clear()
	var claimed: Dictionary = snapshot.get("claimed", {})
	for key in claimed.keys():
		_claimed[String(key)] = int(claimed[key])
	if snapshot.has("empty"):
		var empty: Dictionary = snapshot["empty"]
		for key in empty.keys():
			_empty_since[String(key)] = int(empty[key])
		var refilled: Dictionary = snapshot["refilled"]
		for key in refilled.keys():
			_refilled[String(key)] = int(refilled[key])
		# Older saves recorded a plain restock "day" rather than a plan —
		# treat that as "already handled today" so loading doesn't
		# immediately fire a redundant restock.
		_restock_plan_day = int(snapshot.get("restock_plan_day", snapshot.get("day", 0)))
		_restock_hour = float(snapshot.get("restock_hour", RESTOCK_WINDOW_START))
		_restocked_today = bool(snapshot.get("restocked_today", true))
		return
	# Legacy save: the whole dictionary was just the set of looted ids, with no
	# day recorded. Keep them all empty and let the normal restock bring them
	# back the next morning.
	for key in snapshot.keys():
		_empty_since[String(key)] = 0

## Forget the saved spot — next map load starts at the scene's own spawn.
## Also wipes the restock state, so this doubles as "new game".
func clear() -> void:
	player_position = Vector2.ZERO
	has_player_position = false
	camera_zoom = 0.0
	_empty_since.clear()
	_refilled.clear()
	_claimed.clear()
	tow_count = 0
	_restock_plan_day = 0
	_restock_hour = RESTOCK_WINDOW_START
	_restocked_today = false

## Whether a prop that has never been seen before starts full. Deterministic on
## the id, so a reload can't reshuffle which bins the city begins with.
func _starts_full(id: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	return rng.randf() < INITIAL_FULL_CHANCE

## Rolls today's restock moment the first time it's asked about each day, then
## fires it once `get_hour()` reaches that moment. Runs both from `_process()`
## (so it fires live even if nothing else happens to ask) and from
## `is_prop_full()`/`mark_emptied()` (so a save loaded well past this
## morning's window catches up the instant anything checks in).
func _check_restock() -> void:
	var today := DayNightCycle.day
	if today != _restock_plan_day:
		_restock_plan_day = today
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(today)
		_restock_hour = RESTOCK_WINDOW_START + rng.randf() * (RESTOCK_WINDOW_END - RESTOCK_WINDOW_START)
		_restocked_today = false
	if not _restocked_today and DayNightCycle.get_hour() >= _restock_hour:
		_restocked_today = true
		if not _empty_since.is_empty():
			for key in _empty_since.keys():
				_refilled[String(key)] = today
			_empty_since.clear()
			restocked.emit()
