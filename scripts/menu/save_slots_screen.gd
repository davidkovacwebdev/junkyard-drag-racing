class_name SaveSlotsScreen
extends Control
## Picks one of SaveSystem's save profiles. A filled slot loads straight into
## the world; an empty one goes to character creation, which starts a new game
## in it. Delete needs a second press ("Sure?") before the slot is scrapped.

const WORLD_SCENE := "res://scenes/world/main.tscn"
const CHARACTER_CREATION_SCENE := "res://scenes/menu/character_creation.tscn"
const SLOT_BUTTON_HEIGHT := 64.0
const DELETE_BUTTON_WIDTH := 110.0

@onready var _slot_rows: VBoxContainer = $Content/SlotRows

var _delete_armed_slot: int = -1

func _ready() -> void:
	_build_rows()

func _build_rows() -> void:
	for child in _slot_rows.get_children():
		child.queue_free()
	for slot in SaveSystem.SLOT_COUNT:
		_slot_rows.add_child(_make_row(slot))

func _make_row(slot: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var summary := SaveSystem.slot_summary(slot)

	var slot_button := ScrapButton.new()
	slot_button.custom_minimum_size = Vector2(0, SLOT_BUTTON_HEIGHT)
	slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_button.text = _slot_label(slot, summary)
	slot_button.font_size = 24
	slot_button.tilt_degrees = [-1.5, 1.0, -0.5][slot]
	slot_button.jitter_seed = 61 + slot * 7
	slot_button.selected = slot == SaveSystem.current_slot and not summary.is_empty()
	slot_button.pressed.connect(_on_slot_pressed.bind(slot, summary.is_empty()))
	row.add_child(slot_button)

	if not summary.is_empty():
		var delete_button := ScrapButton.new()
		delete_button.custom_minimum_size = Vector2(DELETE_BUTTON_WIDTH, SLOT_BUTTON_HEIGHT)
		delete_button.text = "Sure?" if slot == _delete_armed_slot else "Delete"
		delete_button.font_size = 20
		delete_button.tilt_degrees = [2.0, -1.5, 1.5][slot]
		delete_button.jitter_seed = 83 + slot * 5
		delete_button.pressed.connect(_on_delete_pressed.bind(slot))
		row.add_child(delete_button)
	return row

func _slot_label(slot: int, summary: Dictionary) -> String:
	if summary.is_empty():
		return "Slot %d  -  Empty" % (slot + 1)
	return "Slot %d  -  %s   Day %d   $%d   %d Wins" % [
		slot + 1, str(summary.player_name).to_upper(), summary.day, summary.money, summary.races_won]

func _on_slot_pressed(slot: int, is_empty: bool) -> void:
	SaveSystem.select_slot(slot)
	if is_empty:
		get_tree().change_scene_to_file(CHARACTER_CREATION_SCENE)
		return
	SaveSystem.load_game()
	SceneLoader.change_scene(WORLD_SCENE)

func _on_delete_pressed(slot: int) -> void:
	if _delete_armed_slot != slot:
		_delete_armed_slot = slot
		Sfx.play(&"denied", -8.0)
		_build_rows()
		return
	_delete_armed_slot = -1
	SaveSystem.delete_slot(slot)
	Sfx.play(&"profile_scrapped", -4.0)
	_build_rows()
