class_name ForgeScreen
extends CanvasLayer
## The scrap forge's counter: the player's loose parts on the left, the
## crucibles on the right. Click a part to toss it into a crucible (click the
## crucible to take it back), see what the mash could turn into, and pay the
## smith to hammer it into one new part (see PartForge).
##
## Only loose parts (Inventory.spare_parts) can go in; a part has to come off
## the car in the garage first. The ingredients are taken and the result stowed
## the moment the forge button is pressed, before the hammering plays out, so
## closing the screen mid-animation can't lose anything.

signal closed

const _PART_SLOT_SCENE := preload("res://scenes/garage/part_slot.tscn")
const _OPTION_KEYS := [KEY_1, KEY_2]
const _CATEGORY_NAMES := {
	PartData.Category.BODY: "BODY",
	PartData.Category.ENGINE: "ENGINE",
	PartData.Category.WHEEL: "WHEEL",
}
const HAMMER_BLOWS := 3
const HAMMER_INTERVAL := 0.38
const FLASH_COLOR := Color(1.0, 0.7, 0.2, 0.0)
const BOARD_SIZE := Vector2(1060, 610)

@export var forge_price: int = 60
@export var forge_hours: float = 2.0

@export_group("Lines")
@export var greet_line: String = "Toss two or three loose parts in the pots. I'll melt 'em down and hammer out somethin' new. No refunds."
@export var need_more_line: String = "Need at least two parts in there, pal."
@export var full_line: String = "Three pots, three parts. That's the rule."
@export var broke_line: String = "Coal ain't free. That's $%d."
@export var forged_line: String = "Hah! Came out a %s. Your %s's in the spare pile."

var _crucible_parts: Array[PartData] = []
var _stash_rows: Dictionary = {}
var _busy := false
var _rng := RandomNumberGenerator.new()

var _line_label: Label
var _stash_list: VBoxContainer
var _stash_empty_label: Label
var _crucibles: Array[CrucibleSlot] = []
var _odds_label: Label
var _stats_label: Label
var _result_slot: PartSlot
var _forge_button: ScrapButton
var _leave_button: ScrapButton
var _flash: ColorRect

func _ready() -> void:
	layer = 4
	_rng.randomize()
	_build()
	visible = false

func open() -> void:
	_crucible_parts.clear()
	_clear_stash_rows()
	_result_slot.visible = false
	_line_label.text = greet_line
	_refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	_crucible_parts.clear()
	closed.emit()

func is_open() -> bool:
	return visible

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	var index := _OPTION_KEYS.find(event.keycode)
	if index == -1:
		return
	get_viewport().set_input_as_handled()
	[_forge_button, _leave_button][index].pressed.emit()

# --- Picking parts -------------------------------------------------------------

func _toss_in(part: PartData) -> void:
	if _busy:
		return
	if _crucible_parts.size() >= PartForge.MAX_INGREDIENTS:
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = full_line
		return
	_crucible_parts.append(part)
	_result_slot.visible = false
	Sfx.play(&"crucible_drop", -4.0)
	_refresh()

func _take_out(index: int) -> void:
	if _busy or index >= _crucible_parts.size():
		return
	_crucible_parts.remove_at(index)
	Sfx.play(&"crucible_drop", -8.0)
	_refresh()

# --- Forging -------------------------------------------------------------------

func _forge() -> void:
	if _busy:
		return
	if not PartForge.can_forge(_crucible_parts):
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = need_more_line
		return
	if not Inventory.spend_money(forge_price):
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = broke_line % forge_price
		return
	var result := PartForge.forge(_crucible_parts, _rng)
	for part in _crucible_parts:
		Inventory.take_spare(part)
	Inventory.stow_part(result)
	DayNightCycle.advance_hours(forge_hours)
	SaveSystem.save_game()
	_play_smash(result)

func _play_smash(result: PartData) -> void:
	_busy = true
	_forge_button.disabled = true
	_leave_button.disabled = true
	var tween := create_tween()
	for blow in HAMMER_BLOWS:
		tween.tween_callback(_hammer_blow)
		tween.tween_interval(HAMMER_INTERVAL)
	tween.tween_callback(_reveal.bind(result))

func _hammer_blow() -> void:
	Sfx.play(&"forge_hammer", -3.0)
	_flash.color = FLASH_COLOR
	var flash := create_tween()
	flash.tween_property(_flash, "color:a", 0.35, 0.04)
	flash.tween_property(_flash, "color:a", 0.0, 0.2)
	for crucible in _crucibles:
		var icon := crucible.get_icon()
		var home := icon.position
		var shake := create_tween()
		shake.tween_property(icon, "position", home + Vector2(randf_range(-7.0, 7.0), randf_range(-9.0, 3.0)), 0.04)
		shake.tween_property(icon, "position", home, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _reveal(result: PartData) -> void:
	Sfx.play(&"forge_quench", -4.0)
	_busy = false
	_crucible_parts.clear()
	_line_label.text = forged_line % [_CATEGORY_NAMES[result.category], result.display_name]
	_refresh()
	_result_slot.visible = true
	_result_slot.set_part(result)
	_result_slot.pivot_offset = _result_slot.size / 2.0
	_result_slot.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(_result_slot, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# --- Refreshing ----------------------------------------------------------------

func _refresh() -> void:
	_refresh_stash()
	for i in _crucibles.size():
		_crucibles[i].set_part(_crucible_parts[i] if i < _crucible_parts.size() else null)
	_odds_label.text = _odds_text()
	_stats_label.text = "Forging costs $%d. You have $%d." % [forge_price, Inventory.money]
	_forge_button.text = "1. Forge It ($%d)" % forge_price
	_forge_button.disabled = _busy or not PartForge.can_forge(_crucible_parts)
	_leave_button.disabled = _busy

## One row per part id with how many loose copies are left, like the garage.
## A row per copy means a live SubViewport icon per copy, which freezes the
## game once the stash holds thousands of parts. Existing rows only get their
## count updated; a row is built the first time its part shows up.
func _refresh_stash() -> void:
	var loose_by_id := _loose_by_id()
	for id in _stash_rows.keys():
		if not loose_by_id.has(id):
			_stash_rows[id].visible = false
	var ids := loose_by_id.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return loose_by_id[a][0].display_name < loose_by_id[b][0].display_name)
	for id in ids:
		var copies: Array = loose_by_id[id]
		var slot: PartSlot = _stash_rows.get(id)
		if slot == null:
			slot = _PART_SLOT_SCENE.instantiate()
			_stash_list.add_child(slot)
			slot.category = copies[0].category
			slot.set_part(copies[0], copies.size())
			slot.gui_input.connect(_on_stash_slot_input.bind(id))
			_stash_rows[id] = slot
		else:
			slot.set_count(copies.size())
		slot.visible = true
	for i in ids.size():
		_stash_list.move_child(_stash_rows[ids[i]], i)
	_stash_empty_label.visible = ids.is_empty()

func _clear_stash_rows() -> void:
	for slot in _stash_rows.values():
		slot.queue_free()
	_stash_rows.clear()

## Loose parts not already in a crucible, grouped as {id: [PartData, ...]}.
func _loose_by_id() -> Dictionary:
	var grouped := {}
	for part in Inventory.spare_parts:
		if part == null or _crucible_parts.has(part):
			continue
		if not grouped.has(part.id):
			grouped[part.id] = []
		grouped[part.id].append(part)
	return grouped

func _odds_text() -> String:
	if _crucible_parts.size() < PartForge.MIN_INGREDIENTS:
		return "Toss in %d or %d parts." % [PartForge.MIN_INGREDIENTS, PartForge.MAX_INGREDIENTS]
	var odds := PartForge.category_odds(_crucible_parts)
	var chances := PackedStringArray()
	for category in odds:
		chances.append("%s %d%%" % [_CATEGORY_NAMES[category], roundi(float(odds[category]) * 100.0)])
	return "Could come out as:  " + "   ".join(chances)

func _on_stash_slot_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var copies: Array = _loose_by_id().get(id, [])
		if not copies.is_empty():
			_toss_in(copies[0])

# --- Layout --------------------------------------------------------------------

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var board := ScrapPanel.new()
	board.set_anchors_preset(Control.PRESET_CENTER)
	board.offset_left = -BOARD_SIZE.x / 2.0
	board.offset_right = BOARD_SIZE.x / 2.0
	board.offset_top = -BOARD_SIZE.y / 2.0
	board.offset_bottom = BOARD_SIZE.y / 2.0
	board.tilt_degrees = -0.6
	board.jitter_seed = 73
	backdrop.add_child(board)

	var plate := ScrapPanel.new()
	plate.body_color = UiPalette.ACCENT_YELLOW
	plate.shade_color = UiPalette.ACCENT_YELLOW.darkened(0.15)
	plate.skirt_color = UiPalette.ACCENT_YELLOW.darkened(0.3)
	plate.nails = false
	plate.tilt_degrees = 1.5
	plate.jitter_seed = 74
	plate.position = Vector2(24, -22)
	plate.size = Vector2(250, 50)
	board.add_child(plate)
	var title := _label("SCRAP FORGE", 28, UiPalette.INK)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(title)

	_line_label = _label("", 18, UiPalette.TEXT_LIGHT)
	_line_label.position = Vector2(300, 18)
	_line_label.size = Vector2(BOARD_SIZE.x - 330, 60)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.add_child(_line_label)

	var stash_title := _label("YOUR LOOSE PARTS  (click to toss in)", 16, UiPalette.TEXT_LIGHT)
	stash_title.position = Vector2(28, 88)
	board.add_child(stash_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(26, 116)
	scroll.size = Vector2(480, BOARD_SIZE.y - 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board.add_child(scroll)
	_stash_list = VBoxContainer.new()
	_stash_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stash_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_stash_list)
	_stash_empty_label = _label("No loose parts.\nTake some off in the garage,\nor dig some up at the junkyard.", 18, UiPalette.TEXT_LIGHT)
	_stash_empty_label.position = Vector2(40, 140)
	board.add_child(_stash_empty_label)

	var right := VBoxContainer.new()
	right.position = Vector2(540, 88)
	right.size = Vector2(BOARD_SIZE.x - 570, BOARD_SIZE.y - 110)
	right.add_theme_constant_override("separation", 12)
	board.add_child(right)
	right.add_child(_label("THE CRUCIBLES  (click to take back)", 16, UiPalette.TEXT_LIGHT))
	var pots := HBoxContainer.new()
	pots.add_theme_constant_override("separation", 20)
	right.add_child(pots)
	for i in PartForge.MAX_INGREDIENTS:
		var crucible := CrucibleSlot.new()
		pots.add_child(crucible)
		crucible.pressed.connect(_take_out.bind(i))
		_crucibles.append(crucible)
	var stripe := HazardStripe.new()
	stripe.custom_minimum_size = Vector2(0, 10)
	right.add_child(stripe)
	_odds_label = _label("", 20, UiPalette.TEXT_LIGHT)
	right.add_child(_odds_label)
	_result_slot = _PART_SLOT_SCENE.instantiate()
	_result_slot.custom_minimum_size = Vector2(0, 96)
	right.add_child(_result_slot)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	_stats_label = _label("", 16, UiPalette.TEXT_LIGHT)
	right.add_child(_stats_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	right.add_child(buttons)
	_forge_button = _button("1. Forge It", Vector2(250, 48), 1.5, 21)
	_forge_button.pressed.connect(_forge)
	buttons.add_child(_forge_button)
	_leave_button = _button("2. Walk Away", Vector2(200, 48), -1.2, 22)
	_leave_button.pressed.connect(close)
	buttons.add_child(_leave_button)

	_flash = ColorRect.new()
	_flash.color = FLASH_COLOR
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, min_size: Vector2, tilt: float, seed: int) -> ScrapButton:
	var button := ScrapButton.new()
	button.text = text
	button.font_size = 20
	button.custom_minimum_size = min_size
	button.tilt_degrees = tilt
	button.jitter_seed = seed
	button.focus_mode = Control.FOCUS_NONE
	return button
