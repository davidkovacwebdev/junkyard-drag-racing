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
## come back. The city starts mostly picked-over and a few bins restock each
## in-game day, so there's always something to find. See `is_prop_full()`.

## Last known player position in world (map) coordinates.
var player_position: Vector2 = Vector2.ZERO
## False until the player has been on the map at least once. Without this
## the first load would snap the player to the origin, which happens to be
## correct here but is not something to rely on.
var has_player_position: bool = false

## Props the player has emptied, and the in-game day each was emptied on. An id
## in here is empty right now; an id that isn't is full. See `is_prop_full()`.
var _empty_since: Dictionary = {}
## Ids a daily restock has put back. Without this record a refilled prop would
## fall back to its "started empty" roll and quietly empty itself again the next
## time the map reloaded.
var _refilled: Dictionary = {}
## Last day the restock has been processed for, so a day only ever restocks once
## even though many props ask "am I full?" on the same frame.
var _restock_day: int = 0

## Chance a prop is full the first time the world is ever generated. Kept low on
## purpose: the city starts mostly picked-over, so finding a full bin is worth a
## detour rather than being the default state.
const INITIAL_FULL_CHANCE := 0.2
## How many emptied props come back per in-game day. The city is restocked a
## trickle at a time (oldest first) rather than all at once, so there's always
## something new to find without the streets refilling wholesale overnight.
const RESTOCK_PER_DAY := 3

func remember_player(position: Vector2) -> void:
	player_position = position
	has_player_position = true

## Whether `id` is full — i.e. worth opening — right now. Every caller wants a
## current answer, so this is also where the daily restock gets advanced.
func is_prop_full(id: String) -> bool:
	if id.is_empty():
		return true
	_process_restock()
	if _empty_since.has(id):
		return false
	if _refilled.has(id):
		return true
	# Never seen before in this save: this is its very first state, rolled
	# stably from the id so the same prop starts the same way on every reload.
	return _starts_full(id)

## Record that a prop was emptied on the current day. It comes back via the
## normal restock, oldest-empty first.
func mark_emptied(id: String) -> void:
	if id.is_empty():
		return
	_process_restock()
	_refilled.erase(id)
	_empty_since[id] = DayNightCycle.day

## How many props are empty right now.
func looted_count() -> int:
	return _empty_since.size()

## Snapshot of the restock state, for SaveSystem to write out.
func get_looted_snapshot() -> Dictionary:
	_process_restock()
	return {
		"empty": _empty_since.duplicate(),
		"refilled": _refilled.duplicate(),
		"day": _restock_day,
	}

## Restore a previously-saved snapshot (SaveSystem on Continue).
func restore_looted(snapshot: Dictionary) -> void:
	_empty_since.clear()
	_refilled.clear()
	_restock_day = 0
	if snapshot.has("empty"):
		var empty: Dictionary = snapshot["empty"]
		for key in empty.keys():
			_empty_since[String(key)] = int(empty[key])
		var refilled: Dictionary = snapshot["refilled"]
		for key in refilled.keys():
			_refilled[String(key)] = int(refilled[key])
		_restock_day = int(snapshot["day"])
		return
	# Legacy save: the whole dictionary was just the set of looted ids, with no
	# day recorded. Keep them all empty and let the normal restock bring them
	# back over the next few days.
	for key in snapshot.keys():
		_empty_since[String(key)] = 0

## Forget the saved spot — next map load starts at the scene's own spawn.
## Also wipes the restock state, so this doubles as "new game".
func clear() -> void:
	player_position = Vector2.ZERO
	has_player_position = false
	_empty_since.clear()
	_refilled.clear()
	_restock_day = 0

## Whether a prop that has never been seen before starts full. Deterministic on
## the id, so a reload can't reshuffle which bins the city begins with.
func _starts_full(id: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	return rng.randf() < INITIAL_FULL_CHANCE

## Advance the restock day by day up to today. Cheap after the first call on a
## given day, and it catches up properly if the player spent days off the map.
func _process_restock() -> void:
	var today := DayNightCycle.day
	if _restock_day <= 0:
		# First look of a new game: seed to today so day one has no restock.
		_restock_day = today
		return
	while _restock_day < today:
		_restock_day += 1
		_restock_one_day()

## Put back up to RESTOCK_PER_DAY props, oldest-empty first. That ordering is
## what turns a long absence into a gradual trickle instead of one flood.
func _restock_one_day() -> void:
	var candidates: Array[Array] = []
	for key in _empty_since.keys():
		var id := String(key)
		var since := int(_empty_since[id])
		if since < _restock_day:
			candidates.append([since, id])
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		return String(a[1]) < String(b[1]))
	var count := mini(RESTOCK_PER_DAY, candidates.size())
	for i in count:
		var id := String(candidates[i][1])
		_empty_since.erase(id)
		_refilled[id] = _restock_day
