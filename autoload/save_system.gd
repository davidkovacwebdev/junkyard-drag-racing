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
## A big inventory takes hundreds of milliseconds to write, so the periodic
## autosave writes on a worker thread from a snapshot. Every save writes to a
## temp file and swaps it in, so quitting mid-write never corrupts the save.
##
## Never actually writes while sitting on the main menu — otherwise the
## periodic tick could clobber an existing save before the player has
## even chosen Continue. That's a live check against the current scene
## every time, not a flag some caller has to remember to flip, so
## there's nowhere for it to get stuck wrong.

const SAVE_PATH := "user://save.tres"
const TEMP_SAVE_PATH := "user://save.tmp.tres"
const AUTOSAVE_INTERVAL := 10.0

var _autosave_timer: float = 0.0
var _background_save_task: int = -1

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		_save_in_background()

func _exit_tree() -> void:
	_wait_for_background_save()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	if _on_main_menu():
		return
	_wait_for_background_save()
	_write_save(_snapshot())

func _save_in_background() -> void:
	if _on_main_menu() or _background_save_task != -1:
		return
	var data := _snapshot()
	_background_save_task = WorkerThreadPool.add_task(_write_save.bind(data))

func _wait_for_background_save() -> void:
	if _background_save_task == -1:
		return
	WorkerThreadPool.wait_for_task_completion(_background_save_task)
	_background_save_task = -1

## Copies the arrays (and deep-copies the few cars, which get edited in the
## garage) so gameplay can keep changing things while a worker writes.
func _snapshot() -> SaveData:
	var data := SaveData.new()
	var cars: Array[CarModelData] = []
	for car in Inventory.owned_cars:
		cars.append(car.duplicate(true))
	data.owned_cars = cars
	data.selected_index = Inventory.selected_index
	data.garage_capacity = Inventory.garage_capacity
	data.scrap = Inventory.scrap
	data.money = Inventory.money
	data.spare_parts = Inventory.spare_parts.duplicate()
	data.player_position = WorldState.player_position
	data.has_player_position = WorldState.has_player_position
	data.looted = WorldState.get_looted_snapshot()
	data.races_won = RaceProgression.races_won
	data.day = DayNightCycle.day
	data.time_of_day = DayNightCycle.time_of_day
	return data

func _write_save(data: SaveData) -> void:
	var err := ResourceSaver.save(data, TEMP_SAVE_PATH)
	if err == OK:
		err = DirAccess.rename_absolute(TEMP_SAVE_PATH, SAVE_PATH)
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
	Inventory.spare_parts = data.spare_parts
	WorldState.player_position = data.player_position
	WorldState.has_player_position = data.has_player_position
	WorldState.restore_looted(data.looted)
	RaceProgression.races_won = data.races_won
	DayNightCycle.day = data.day
	DayNightCycle.time_of_day = data.time_of_day
	return true

## Called by New Game so starting over doesn't leave a stale save
## sitting there claiming to be continuable.
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func _on_main_menu() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.name == "MainMenu"
