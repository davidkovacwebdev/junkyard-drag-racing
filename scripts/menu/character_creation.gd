extends Control
## New Game's first screen: the player types a name and builds their own
## character from the same part scenes the editor's Character Creator dock
## uses. Each slot is a row of "<  part name  >" arrows; Randomize rolls a
## whole outfit. Parts marked `npc_only` (Grandpa's wheelchair, beard, ...)
## never show up here.
##
## Nothing is wiped until "Hit the Road": backing out to the save slots leaves
## the chosen slot alone. Starting resets the world for a fresh game, stores
## the name and look in PlayerProfile and drives into the open world.

const WORLD_SCENE := "res://scenes/world/main.tscn"
## Top to bottom, the same order the parts sit on the body.
const SLOT_ORDER: Array[CharacterPartData.Slot] = [
	CharacterPartData.Slot.HEAD,
	CharacterPartData.Slot.HAIR,
	CharacterPartData.Slot.EYES,
	CharacterPartData.Slot.ACCESSORY,
	CharacterPartData.Slot.TORSO,
	CharacterPartData.Slot.LEGS,
	CharacterPartData.Slot.BOOTS,
]
## Slots that may be left empty. The rest always wear something, so the
## player can't end up a floating head.
const OPTIONAL_SLOTS: Array[CharacterPartData.Slot] = [
	CharacterPartData.Slot.HAIR,
	CharacterPartData.Slot.ACCESSORY,
]
const RANDOM_EMPTY_CHANCE := 0.25
const ROW_HEIGHT := 38.0
const ARROW_WIDTH := 46.0
const POP_SCALE := 1.08

@onready var _rows: VBoxContainer = $Content/Board/Rows
@onready var _name_edit: LineEdit = $Content/Board/Rows/NameRow/NameEdit
@onready var _preview: Node2D = $Content/PreviewBoard/Character
@onready var _name_label: Label = $Content/PreviewBoard/NameLabel
@onready var _start_button: ScrapButton = $Content/StartButton
@onready var _randomize_button: ScrapButton = $Content/RandomizeButton

## Slot -> the scenes the player can pick, with null first for optional slots.
var _choices: Dictionary = {}
## Slot -> index into _choices[slot].
var _picked: Dictionary = {}
## Slot -> the Label showing the picked part's name.
var _part_labels: Dictionary = {}
var _part_names: Dictionary = {}  # PackedScene -> display name
var _character := CharacterData.new()
var _preview_base_scale := Vector2.ONE
var _pop_tween: Tween

func _ready() -> void:
	_preview_base_scale = _preview.scale
	_load_choices()
	for i in SLOT_ORDER.size():
		_rows.add_child(_build_slot_row(SLOT_ORDER[i], i))
	_name_edit.max_length = PlayerProfile.MAX_NAME_LENGTH
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _start())
	_randomize_button.pressed.connect(_on_randomize_pressed)
	_start_button.pressed.connect(_start)
	# Starts plain: hair and accessory begin on "None" and the player adds them.
	_roll_outfit(true)
	_on_name_changed(_name_edit.text)
	_name_edit.grab_focus.call_deferred()

func _load_choices() -> void:
	var parts := CharacterDatabase.scan_player_parts()
	for slot in SLOT_ORDER:
		var scenes: Array = []
		if OPTIONAL_SLOTS.has(slot):
			scenes.append(null)
		for entry in parts.get(slot, []):
			scenes.append(entry.scene)
			_part_names[entry.scene] = String(entry.data.display_name)
		_choices[slot] = scenes
		_picked[slot] = 0

func _build_slot_row(slot: CharacterPartData.Slot, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var caption := Label.new()
	caption.text = CharacterPartData.slot_name(slot)
	caption.custom_minimum_size = Vector2(120, 0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", UiPalette.TEXT_BROWN)
	caption.add_theme_font_size_override("font_size", 22)
	row.add_child(caption)

	row.add_child(_make_arrow("<", slot, -1, index * 2))

	var part_label := Label.new()
	part_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	part_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	part_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	part_label.clip_text = true
	part_label.add_theme_color_override("font_color", UiPalette.TEXT_BROWN)
	part_label.add_theme_font_size_override("font_size", 20)
	_part_labels[slot] = part_label
	row.add_child(part_label)

	row.add_child(_make_arrow(">", slot, 1, index * 2 + 1))
	return row

func _make_arrow(label: String, slot: CharacterPartData.Slot, step: int, seed_offset: int) -> ScrapButton:
	var arrow := ScrapButton.new()
	arrow.text = label
	arrow.font_size = 22
	arrow.custom_minimum_size = Vector2(ARROW_WIDTH, ROW_HEIGHT)
	arrow.tilt_degrees = 2.0 if seed_offset % 2 == 0 else -2.0
	arrow.jitter_seed = 200 + seed_offset
	arrow.focus_mode = Control.FOCUS_NONE
	arrow.disabled = (_choices[slot] as Array).size() < 2
	arrow.pressed.connect(_cycle.bind(slot, step))
	return arrow

func _cycle(slot: CharacterPartData.Slot, step: int) -> void:
	var count := (_choices[slot] as Array).size()
	if count == 0:
		return
	_picked[slot] = posmod(int(_picked[slot]) + step, count)
	Sfx.play(&"outfit_swap", -8.0, 0.1)
	_refresh()

func _on_randomize_pressed() -> void:
	_roll_outfit()
	Sfx.play(&"outfit_swap", -6.0, 0.1)

## Rolls a random part for every slot. With `leave_optional_empty`, the
## optional slots stay on "None" instead.
func _roll_outfit(leave_optional_empty: bool = false) -> void:
	for slot in SLOT_ORDER:
		var scenes: Array = _choices[slot]
		if scenes.is_empty():
			continue
		var optional := OPTIONAL_SLOTS.has(slot)
		if optional and (leave_optional_empty or randf() < RANDOM_EMPTY_CHANCE):
			_picked[slot] = 0
		else:
			# Optional slots keep "None" at index 0, so roll past it.
			var first := 1 if optional and scenes.size() > 1 else 0
			_picked[slot] = randi_range(first, scenes.size() - 1)
	_refresh()

func _refresh() -> void:
	for slot in SLOT_ORDER:
		var scenes: Array = _choices[slot]
		var scene: PackedScene = scenes[_picked[slot]] if not scenes.is_empty() else null
		_character.set_part(slot, scene)
		(_part_labels[slot] as Label).text = _part_names.get(scene, "None")
	for child in _preview.get_children():
		child.free()
	CharacterAssembler.assemble(_character, _preview, Vector2.ZERO)
	_pop_preview()

## A quick squash-and-stretch so each change lands with a bump.
func _pop_preview() -> void:
	if _pop_tween != null:
		_pop_tween.kill()
	_preview.scale = _preview_base_scale * Vector2(1.0 / POP_SCALE, POP_SCALE)
	_pop_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_preview, "scale", _preview_base_scale, 0.4)

func _on_name_changed(text: String) -> void:
	var cleaned := PlayerProfile.clean_name(text)
	_name_label.text = cleaned.to_upper()
	_start_button.disabled = cleaned.is_empty()

func _start() -> void:
	var player_name := PlayerProfile.clean_name(_name_edit.text)
	if player_name.is_empty():
		Sfx.play(&"denied", -6.0)
		_name_edit.grab_focus()
		return
	Inventory.reset()
	WorldState.clear()
	WorldState.remember_player(StoryDirector.OPENING_CAR_SPOT)
	RaceProgression.reset()
	DayNightCycle.reset()
	Cutscenes.clear_seen()
	Quests.reset()
	Drunk.reset()
	SaveSystem.delete_save()
	_character.display_name = player_name
	PlayerProfile.player_name = player_name
	PlayerProfile.character = _character
	Sfx.play(&"door_close", -4.0)
	get_tree().change_scene_to_file(WORLD_SCENE)
