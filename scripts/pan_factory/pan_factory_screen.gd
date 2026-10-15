class_name PanFactoryScreen
extends CanvasLayer
## Inside the pan factory: the player's loose parts on the left, the workbench
## on the right. Click a part to put it on the bench, turn it (Q / E, the
## buttons or the mouse wheel) so the side to bend faces up, pick one of three
## hammers and click the part to whack a dent into it (PartDent), $50 a blow. Dents bend
## the part's collision outline too, so a bashed part handles differently.
##
## Only loose parts (Inventory.spare_parts) go on the bench; a part has to come
## off the car in the garage first. Each blow is paid and saved the moment it
## lands, so closing the screen can't lose anything.

signal closed

const _PART_SLOT_SCENE := preload("res://scenes/garage/part_slot.tscn")
const _HAMMER_KEYS := [KEY_1, KEY_2, KEY_3]
const _HAMMERS := [PartDent.Hammer.TACK, PartDent.Hammer.CLAW, PartDent.Hammer.SLEDGE]
## Higher for the little hammer, lower for the sledge.
const _HAMMER_PITCH := { PartDent.Hammer.TACK: 1.4, PartDent.Hammer.CLAW: 1.0, PartDent.Hammer.SLEDGE: 0.68 }
const BOARD_SIZE := Vector2(1060, 610)
## Blows closer together than this are ignored, so a double click is one blow.
const BLOW_COOLDOWN := 0.18
## How far Q / E and the turn buttons turn the part.
const TURN_DEGREES := 45.0

@export var hit_price: int = 50

@export_group("Lines")
@export var greet_line: String = "Pan factory. We bend metal for a living. Pick a part, pick a hammer, and every whack is $%d."
@export var pick_line: String = "On the bench it goes. Click where you want it bent."
@export var empty_bench_line: String = "Put somethin' on the bench first, pal."
@export var broke_line: String = "That's $%d a whack. Come back with money."
@export var miss_line: String = "You missed the whole thing. That one's free."
@export var hit_lines: PackedStringArray = PackedStringArray([
	"BONK. Beautiful.",
	"Now that's a dent.",
	"Ooh, that changed the shape alright.",
	"Like a pan after a bar fight.",
	"Keep goin', it's your money.",
])

var _stash_rows: Dictionary = {}
var _hammer: PartDent.Hammer = PartDent.Hammer.CLAW
var _blow_ready_at := 0

var _line_label: Label
var _stash_list: VBoxContainer
var _stash_empty_label: Label
var _stash_sort_button: SortButton
var _bench: DentBench
var _bench_label: Label
var _stats_label: Label
var _hammer_buttons: Array[ScrapButton] = []
var _turn_buttons: Array[ScrapButton] = []
var _leave_button: ScrapButton

func _ready() -> void:
	layer = 4
	_build()
	visible = false

func open() -> void:
	_clear_stash_rows()
	_bench.set_part(null)
	_line_label.text = greet_line % hit_price
	_refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	_bench.set_part(null)
	closed.emit()

func is_open() -> bool:
	return visible

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo \
			or event.is_command_or_control_pressed():
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_4:
		get_viewport().set_input_as_handled()
		close()
		return
	if event.keycode == KEY_Q or event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_turn(TURN_DEGREES * (1.0 if event.keycode == KEY_E else -1.0))
		return
	var index := _HAMMER_KEYS.find(event.keycode)
	if index != -1:
		get_viewport().set_input_as_handled()
		_pick_hammer(_HAMMERS[index])

# --- Bench ---------------------------------------------------------------------

func _put_on_bench(part: PartData) -> void:
	_bench.set_part(part)
	Sfx.play(&"wood_clonk", -8.0)
	_line_label.text = pick_line
	_refresh()

func _pick_hammer(hammer: PartDent.Hammer) -> void:
	_hammer = hammer
	_bench.hammer = hammer
	_refresh()

func _turn(degrees: float) -> void:
	if _bench.part() == null:
		return
	_bench.turn(degrees)
	_turn_sound()

## A ratchety vice crank as the part's turned on the bench.
func _turn_sound() -> void:
	Sfx.play(&"part_unbolt", -12.0)

func _strike(point: Vector2, direction: Vector2) -> void:
	var part := _bench.part()
	if part == null:
		_line_label.text = empty_bench_line
		return
	if Time.get_ticks_msec() < _blow_ready_at:
		return
	_blow_ready_at = Time.get_ticks_msec() + int(BLOW_COOLDOWN * 1000.0)
	if not Inventory.can_afford(hit_price):
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = broke_line % hit_price
		return
	var old_id := part.id
	if not PartDent.hit(part, point, _hammer, direction):
		Sfx.play(&"axe_whoosh", -8.0)
		_bench.swing(point)
		_line_label.text = miss_line
		return
	Inventory.spend_money(hit_price)
	var bonk := Sfx.play(&"pan_bonk", -4.0, 0.06)
	if bonk != null:
		bonk.pitch_scale *= _HAMMER_PITCH[_hammer]
	_bench.swing(point)
	_bench.set_part(part)
	_line_label.text = hit_lines[randi() % hit_lines.size()]
	# The part's icon is stale now, and its first dent gives it a new id.
	_drop_stash_row(old_id)
	_drop_stash_row(part.id)
	SaveSystem.save_game()
	_refresh()

# --- Refreshing ----------------------------------------------------------------

func _refresh() -> void:
	_refresh_stash()
	for i in _hammer_buttons.size():
		_hammer_buttons[i].selected = _HAMMERS[i] == _hammer
	var part := _bench.part()
	_bench_label.text = "THE BENCH" if part == null \
			else "THE BENCH:  %s  (click to whack, wheel to turn)" % part.display_name.to_upper()
	for button in _turn_buttons:
		button.disabled = part == null
	_stats_label.text = "%s: $%d a whack. You have $%d." % [PartDent.NAMES[_hammer], hit_price, Inventory.money]

## One row per part id with how many loose copies are left, like the forge.
func _refresh_stash() -> void:
	var loose_by_id := _loose_by_id()
	for id in _stash_rows.keys():
		if not loose_by_id.has(id):
			_stash_rows[id].visible = false
	var ids := loose_by_id.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return PartSort.comes_before(loose_by_id[a][0], loose_by_id[b][0], _stash_sort_button.key))
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

func _drop_stash_row(id: StringName) -> void:
	var slot: PartSlot = _stash_rows.get(id)
	if slot != null:
		slot.queue_free()
		_stash_rows.erase(id)

func _clear_stash_rows() -> void:
	for slot in _stash_rows.values():
		slot.queue_free()
	_stash_rows.clear()

## Loose parts grouped as {id: [PartData, ...]}, the one on the bench first.
func _loose_by_id() -> Dictionary:
	var grouped := {}
	for part in Inventory.spare_parts:
		if part == null:
			continue
		if not grouped.has(part.id):
			grouped[part.id] = []
		if part == _bench.part():
			grouped[part.id].push_front(part)
		else:
			grouped[part.id].append(part)
	return grouped

func _on_stash_slot_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var copies: Array = _loose_by_id().get(id, [])
		if not copies.is_empty():
			_put_on_bench(copies[0])

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
	board.tilt_degrees = 0.7
	board.jitter_seed = 91
	backdrop.add_child(board)

	var plate := ScrapPanel.new()
	plate.body_color = UiPalette.ACCENT_YELLOW
	plate.shade_color = UiPalette.ACCENT_YELLOW.darkened(0.15)
	plate.skirt_color = UiPalette.ACCENT_YELLOW.darkened(0.3)
	plate.nails = false
	plate.tilt_degrees = -1.5
	plate.jitter_seed = 92
	plate.position = Vector2(24, -22)
	plate.size = Vector2(250, 50)
	board.add_child(plate)
	var title := _label("PAN FACTORY", 28, UiPalette.INK)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(title)

	_line_label = _label("", 18, UiPalette.TEXT_LIGHT)
	_line_label.position = Vector2(300, 18)
	_line_label.size = Vector2(BOARD_SIZE.x - 330, 60)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.add_child(_line_label)

	var stash_title := _label("LOOSE PARTS (click to bench)", 16, UiPalette.TEXT_LIGHT)
	stash_title.position = Vector2(28, 88)
	board.add_child(stash_title)
	_stash_sort_button = SortButton.new()
	_stash_sort_button.font_size = 15
	_stash_sort_button.tilt_degrees = -1.0
	_stash_sort_button.jitter_seed = 93
	_stash_sort_button.position = Vector2(296, 76)
	_stash_sort_button.size = Vector2(170, 34)
	_stash_sort_button.sort_changed.connect(func(_key: PartSort.Key) -> void: _refresh_stash())
	board.add_child(_stash_sort_button)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(26, 116)
	scroll.size = Vector2(440, BOARD_SIZE.y - 150)
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
	right.position = Vector2(496, 88)
	right.size = Vector2(BOARD_SIZE.x - 526, BOARD_SIZE.y - 110)
	right.add_theme_constant_override("separation", 12)
	board.add_child(right)
	_bench_label = _label("", 16, UiPalette.TEXT_LIGHT)
	right.add_child(_bench_label)
	_bench = DentBench.new()
	_bench.custom_minimum_size = Vector2(0, 262)
	_bench.struck.connect(_strike)
	_bench.turned.connect(_turn_sound)
	right.add_child(_bench)
	var turns := HBoxContainer.new()
	turns.add_theme_constant_override("separation", 12)
	right.add_child(turns)
	for i in 2:
		var button := _button(["Q. Turn Left", "E. Turn Right"][i], Vector2(166, 40), [-1.0, 1.4][i], 98 + i)
		button.font_size = 18
		button.pressed.connect(_turn.bind(TURN_DEGREES * (1.0 if i == 1 else -1.0)))
		turns.add_child(button)
		_turn_buttons.append(button)
	var hammers := HBoxContainer.new()
	hammers.add_theme_constant_override("separation", 12)
	right.add_child(hammers)
	for i in _HAMMERS.size():
		var button := _button("%d. %s" % [i + 1, PartDent.NAMES[_HAMMERS[i]]], Vector2(166, 46), [1.2, -0.8, 1.6][i], 94 + i)
		button.font_size = 18
		button.pressed.connect(_pick_hammer.bind(_HAMMERS[i]))
		hammers.add_child(button)
		_hammer_buttons.append(button)
	var stripe := HazardStripe.new()
	stripe.custom_minimum_size = Vector2(0, 10)
	right.add_child(stripe)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	right.add_child(bottom)
	_stats_label = _label("", 16, UiPalette.TEXT_LIGHT)
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_stats_label)
	_leave_button = _button("4. Walk Away", Vector2(190, 46), -1.2, 97)
	_leave_button.pressed.connect(close)
	bottom.add_child(_leave_button)

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
