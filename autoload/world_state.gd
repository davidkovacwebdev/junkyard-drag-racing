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

## Last known player position in world (map) coordinates.
var player_position: Vector2 = Vector2.ZERO
## False until the player has been on the map at least once. Without this
## the first load would snap the player to the origin, which happens to be
## correct here but is not something to rely on.
var has_player_position: bool = false

## Ids of the roadside trash props already looted. The props themselves are
## regenerated from a seed every time main.tscn loads, so without this the whole
## city would refill each time the player stepped into the garage.
var _looted: Dictionary = {}

func remember_player(position: Vector2) -> void:
	player_position = position
	has_player_position = true

## Record that a trash prop is spent, so it respawns empty next visit.
func mark_looted(id: String) -> void:
	_looted[id] = true

func is_looted(id: String) -> bool:
	return _looted.has(id)

## How many trash props have been cleaned out so far.
func looted_count() -> int:
	return _looted.size()

## Snapshot of looted ids, for SaveSystem to write out.
func get_looted_snapshot() -> Dictionary:
	return _looted.duplicate()

## Restore a previously-saved snapshot (SaveSystem on Continue).
func restore_looted(snapshot: Dictionary) -> void:
	_looted = snapshot.duplicate()

## Forget the saved spot — next map load starts at the scene's own spawn.
## Not used yet; here so a future "new game"/teleport doesn't leave a stale
## position behind.
func clear() -> void:
	player_position = Vector2.ZERO
	has_player_position = false
	_looted.clear()
