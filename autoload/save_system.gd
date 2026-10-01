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
## Never actually writes while on a menu screen (anything under
## scenes/menu: the main menu, settings, credits, character creation) —
## otherwise the periodic tick could clobber an existing save with a blank
## game before the player has even picked a slot. That's a live check
## against the current scene every time, not a flag some caller has to
## remember to flip, so there's nowhere for it to get stuck wrong.
##
## Running with `-- --no-save` (probes and tools) never writes or deletes
## the save, so a test run can't clobber the player's progress.
##
## There are SLOT_COUNT save profiles. Everything reads/writes current_slot,
## which the save slots screen picks; the last one played is remembered in
## settings.cfg so the slots screen highlights it. Each slot also gets a tiny summary
## file so the slots screen never has to load a whole save.

const MENU_SCENES_DIR := "res://scenes/menu/"
const SLOT_COUNT := 3
const SAVE_PATH_PATTERN := "user://save_%d.tres"
const TEMP_SAVE_PATH_PATTERN := "user://save_%d.tmp.tres"
const SUMMARY_PATH_PATTERN := "user://save_%d_summary.cfg"
const LEGACY_SAVE_PATH := "user://save.tres"
const SETTINGS_PATH := "user://settings.cfg"
const AUTOSAVE_INTERVAL := 10.0

var _saving_disabled := "--no-save" in OS.get_cmdline_user_args()
var current_slot: int = 0

var _autosave_timer: float = 0.0
var _background_save_task: int = -1

func _ready() -> void:
	current_slot = _load_last_slot()
	if _saving_disabled:
		set_process(false)
	else:
		_migrate_legacy_save()

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		_save_in_background()

func _exit_tree() -> void:
	_wait_for_background_save()

func has_save() -> bool:
	return slot_has_save(current_slot)

func slot_has_save(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_PATH_PATTERN % slot)

func select_slot(slot: int) -> void:
	_wait_for_background_save()
	current_slot = clampi(slot, 0, SLOT_COUNT - 1)
	if _saving_disabled:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("save", "last_slot", current_slot)
	config.save(SETTINGS_PATH)

## Name/day/money/races for the slots screen, or an empty dictionary when the
## slot is empty. Older saves without a summary file get one built here.
func slot_summary(slot: int) -> Dictionary:
	if not slot_has_save(slot):
		return {}
	var config := ConfigFile.new()
	if config.load(SUMMARY_PATH_PATTERN % slot) != OK:
		var data := ResourceLoader.load(SAVE_PATH_PATTERN % slot, "SaveData", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
		if data == null:
			return {}
		_write_summary(data, slot)
		return _summary_of(data)
	var summary := {}
	for key in config.get_section_keys("summary"):
		summary[key] = config.get_value("summary", key)
	return summary

func save_game() -> void:
	if _saving_disabled or _on_menu_screen():
		return
	_wait_for_background_save()
	_write_save(_snapshot(), current_slot)

func _save_in_background() -> void:
	if _on_menu_screen() or _background_save_task != -1:
		return
	var data := _snapshot()
	_background_save_task = WorkerThreadPool.add_task(_write_save.bind(data, current_slot))

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
	data.owned_items = Inventory.owned_items.duplicate()
	data.player_position = WorldState.player_position
	data.has_player_position = WorldState.has_player_position
	data.looted = WorldState.get_looted_snapshot()
	data.races_won = RaceProgression.races_won
	data.day = DayNightCycle.day
	data.time_of_day = DayNightCycle.time_of_day
	data.seen_cutscenes = Cutscenes.get_seen()
	data.player_name = PlayerProfile.player_name
	data.player_character = PlayerProfile.character
	data.quests_active = Quests.active.duplicate()
	data.quests_completed = Quests.completed.duplicate()
	data.tracked_quest = Quests.tracked
	data.quests_ready = Quests.ready_ids.duplicate()
	data.quests_available = Quests.available.duplicate()
	return data

func _write_save(data: SaveData, slot: int) -> void:
	var err := ResourceSaver.save(data, TEMP_SAVE_PATH_PATTERN % slot)
	if err == OK:
		err = DirAccess.rename_absolute(TEMP_SAVE_PATH_PATTERN % slot, SAVE_PATH_PATTERN % slot)
	if err != OK:
		push_warning("SaveSystem: save failed (error %d)" % err)
		return
	_write_summary(data, slot)

func _write_summary(data: SaveData, slot: int) -> void:
	var config := ConfigFile.new()
	var summary := _summary_of(data)
	for key in summary:
		config.set_value("summary", key, summary[key])
	config.save(SUMMARY_PATH_PATTERN % slot)

func _summary_of(data: SaveData) -> Dictionary:
	return {
		"player_name": data.player_name,
		"day": data.day,
		"money": data.money,
		"races_won": data.races_won,
	}

## Loads the save into Inventory/WorldState. False (and leaves both
## untouched) if there's nothing to load or it fails to read.
func load_game() -> bool:
	if not has_save():
		return false
	var data := ResourceLoader.load(SAVE_PATH_PATTERN % current_slot, "SaveData", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if data == null:
		return false
	Inventory.owned_cars = data.owned_cars
	Inventory.selected_index = data.selected_index
	Inventory.garage_capacity = data.garage_capacity
	Inventory.scrap = data.scrap
	Inventory.money = data.money
	Inventory.spare_parts = data.spare_parts
	Inventory.owned_items = data.owned_items
	WorldState.player_position = data.player_position
	WorldState.has_player_position = data.has_player_position
	WorldState.restore_looted(data.looted)
	RaceProgression.races_won = data.races_won
	DayNightCycle.day = data.day
	DayNightCycle.time_of_day = data.time_of_day
	Cutscenes.restore_seen(data.seen_cutscenes)
	PlayerProfile.player_name = data.player_name
	PlayerProfile.character = data.player_character
	Quests.restore(data.quests_active, data.quests_completed, data.quests_ready,
			data.quests_available, data.tracked_quest)
	return true

## Called by New Game so starting over doesn't leave a stale save
## sitting there claiming to be continuable.
func delete_save() -> void:
	delete_slot(current_slot)

func delete_slot(slot: int) -> void:
	if _saving_disabled:
		return
	if slot == current_slot:
		_wait_for_background_save()
	for path in [SAVE_PATH_PATTERN % slot, SUMMARY_PATH_PATTERN % slot]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _load_last_slot() -> int:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return 0
	return clampi(config.get_value("save", "last_slot", 0), 0, SLOT_COUNT - 1)

## Saves from before profiles existed become slot 1.
func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not slot_has_save(0):
		DirAccess.rename_absolute(LEGACY_SAVE_PATH, SAVE_PATH_PATTERN % 0)

func _on_menu_screen() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.begins_with(MENU_SCENES_DIR)
