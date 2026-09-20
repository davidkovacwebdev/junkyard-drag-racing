extends Node
## Autosave/continue (autoload singleton "SaveSystem"). Saves as one
## Resource (SaveData) via ResourceSaver — CarModelData/PartData were
## built as Resources specifically so this works without any manual
## (de)serialization of the car/part graph.
##
## Ticks a periodic autosave, and callers also save explicitly at
## natural checkpoints (BackButton on leaving any place, PauseMenu on
## quit) so a session ending abruptly loses at most a few seconds.
##
## Never actually writes while sitting on the main menu — otherwise the
## periodic tick could clobber an existing save before the player has
## even chosen Continue. That's a live check against the current scene
## every time, not a flag some caller has to remember to flip, so
## there's nowhere for it to get stuck wrong.

const SAVE_PATH := "user://save.tres"
const AUTOSAVE_INTERVAL := 10.0

var _autosave_timer: float = 0.0

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	if _on_main_menu():
		return
	var data := SaveData.new()
	data.owned_cars = Inventory.owned_cars
	data.selected_index = Inventory.selected_index
	data.garage_capacity = Inventory.garage_capacity
	data.scrap = Inventory.scrap
	data.money = Inventory.money
	data.player_position = WorldState.player_position
	data.has_player_position = WorldState.has_player_position
	data.looted = WorldState.get_looted_snapshot()
	var err := ResourceSaver.save(data, SAVE_PATH)
	if err != OK:
		push_warning("SaveSystem: save failed (error %d)" % err)

## Loads the save into Inventory/WorldState. False (and leaves both
## untouched) if there's nothing to load or it fails to read.
func load_game() -> bool:
	if not has_save():
		return false
	var data := ResourceLoader.load(SAVE_PATH, "SaveData", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null:
		return false
	Inventory.owned_cars = data.owned_cars
	Inventory.selected_index = data.selected_index
	Inventory.garage_capacity = data.garage_capacity
	Inventory.scrap = data.scrap
	Inventory.money = data.money
	WorldState.player_position = data.player_position
	WorldState.has_player_position = data.has_player_position
	WorldState.restore_looted(data.looted)
	return true

## Called by New Game so starting over doesn't leave a stale save
## sitting there claiming to be continuable.
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func _on_main_menu() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.name == "MainMenu"
