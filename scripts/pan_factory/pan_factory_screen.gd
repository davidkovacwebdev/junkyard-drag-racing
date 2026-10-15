class_name PanFactoryScreen
extends CanvasLayer
## Inside the pan factory: the player's loose parts on the left, filtered by
## kind and sorted like the garage's, the workbench on the right. Click a part
## to put it on the bench, turn it (Q / E, the buttons or the mouse wheel), pick
## which side the hammer comes in from (R), which way it swings (T, mirrors it)
## and which of three hammers, and click
## the part to whack a dent into it (PartDent), 20 scrap a blow. Dents bend the
## part's collision outline too, so a bashed part handles differently. A part
## can only be squashed so far (PartDent.MIN_SHAPE); the status line shows how
## much metal is left, and at the floor the hammer just bounces off for free.
##
## Only loose parts go on the bench (LoosePartsPicker, shared with the
## recycler). Each blow is paid and saved the moment it lands, so closing the
## screen can't lose anything.

signal closed

const _HAMMER_KEYS := [KEY_1, KEY_2, KEY_3]
const _HAMMERS := [PartDent.Hammer.TACK, PartDent.Hammer.CLAW, PartDent.Hammer.SLEDGE]
## Higher for the little hammer, lower for the sledge.
const _HAMMER_PITCH := { PartDent.Hammer.TACK: 1.4, PartDent.Hammer.CLAW: 1.0, PartDent.Hammer.SLEDGE: 0.68 }
const BOARD_SIZE := Vector2(1060, 610)
## Blows closer together than this are ignored, so a double click is one blow.
const BLOW_COOLDOWN := 0.18
## How far Q / E and the turn buttons turn the part.
const TURN_DEGREES := 45.0
## Which side the hammer's coming in from, by DentBench.swing_side.
const _SWING_SIDE_NAMES := ["from above", "from the left", "from below", "from the right"]

## Scrap each blow costs.
@export var hit_scrap: int = 20

@export_group("Lines")
@export var greet_line: String = "Pan factory. We bend metal for a living. Pick a part, pick a hammer, and every whack is %d scrap."
@export var pick_line: String = "On the bench it goes. Click where you want it bent."
@export var empty_bench_line: String = "Put somethin' on the bench first, pal."
@export var broke_line: String = "That's %d scrap a whack. Come back with more junk."
@export var miss_line: String = "You missed the whole thing. That one's free."
@export var too_flat_line: String = "That thing's flat as it gets. Any more and there'd be nothin' left. That one's free."
@export var hit_lines: PackedStringArray = PackedStringArray([
	"BONK. Beautiful.",
	"Now that's a dent.",
	"Ooh, that changed the shape alright.",
	"Like a pan after a bar fight.",
	"Keep goin', it's your scrap.",
])

var _hammer: PartDent.Hammer = PartDent.Hammer.CLAW
var _blow_ready_at := 0

var _line_label: Label
var _picker: LoosePartsPicker
var _bench: DentBench
var _bench_label: Label
var _stats_label: Label
var _hammer_buttons: Array[ScrapButton] = []
var _turn_buttons: Array[ScrapButton] = []
var _side_button: ScrapButton
var _leave_button: ScrapButton

func _ready() -> void:
	layer = 4
	_build()
	visible = false

func open() -> void:
	_picker.clear_rows()
	_bench.set_part(null)
	_line_label.text = greet_line % hit_scrap
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
	if event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_turn_hammer()
		return
	if event.keycode == KEY_T:
		get_viewport().set_input_as_handled()
		_mirror_hammer()
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

func _turn_hammer() -> void:
	_bench.turn_hammer()
	Sfx.play(&"wrench_clunk", -12.0)
	_refresh()

func _mirror_hammer() -> void:
	_bench.mirror_hammer()
	var clunk := Sfx.play(&"wrench_clunk", -12.0)
	if clunk != null:
		clunk.pitch_scale *= 1.3
	_refresh()

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
	if Inventory.scrap < hit_scrap:
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = broke_line % hit_scrap
		return
	var old_id := part.id
	match PartDent.hit(part, point, _hammer, direction):
		PartDent.Result.MISSED:
			Sfx.play(&"axe_whoosh", -8.0)
			_bench.swing(point)
			_line_label.text = miss_line
			return
		PartDent.Result.TOO_FLAT:
			# The hammer bounces off metal that won't give any more.
			var clank := Sfx.play(&"anvil_clang", -8.0)
			if clank != null:
				clank.pitch_scale *= 1.2
			_bench.swing(point)
			_line_label.text = too_flat_line
			return
	Inventory.add_scrap(-hit_scrap)
	var bonk := Sfx.play(&"pan_bonk", -4.0, 0.06)
	if bonk != null:
		bonk.pitch_scale *= _HAMMER_PITCH[_hammer]
	_bench.swing(point)
	_bench.set_part(part)
	_line_label.text = hit_lines[randi() % hit_lines.size()]
	# The part's icon is stale now, and its first dent gives it a new id.
	_picker.drop_row(old_id)
	_picker.drop_row(part.id)
	SaveSystem.save_game()
	_refresh()

# --- Refreshing ----------------------------------------------------------------

func _refresh() -> void:
	_picker.pinned = _bench.part()
	_picker.refresh()
	for i in _hammer_buttons.size():
		_hammer_buttons[i].selected = _HAMMERS[i] == _hammer
	var part := _bench.part()
	_bench_label.text = "THE BENCH" if part == null \
			else "THE BENCH:  %s  (click to whack, wheel to turn)" % part.display_name.to_upper()
	for button in _turn_buttons:
		button.disabled = part == null
	var metal := ""
	if part != null:
		var left := PartDent.shape_left(part)
		metal = "  Metal left: %d%%%s." % [roundi(minf(left, 1.0) * 100.0),
				" (can't go flatter)" if left <= PartDent.MIN_SHAPE + 0.005 else ""]
	_stats_label.text = "%s %s%s: %d scrap a whack. You have %d.%s" % [
		PartDent.NAMES[_hammer], _SWING_SIDE_NAMES[_bench.swing_side], ", mirrored" if _bench.mirrored else "",
		hit_scrap, Inventory.scrap, metal]

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

	_picker = LoosePartsPicker.new()
	_picker.title = "LOOSE PARTS (click to bench)"
	_picker.position = Vector2(26, 82)
	_picker.size = Vector2(440, BOARD_SIZE.y - 112)
	_picker.part_picked.connect(_put_on_bench)
	board.add_child(_picker)

	var right := VBoxContainer.new()
	right.position = Vector2(496, 88)
	right.size = Vector2(BOARD_SIZE.x - 526, BOARD_SIZE.y - 110)
	right.add_theme_constant_override("separation", 12)
	board.add_child(right)
	_bench_label = _label("", 16, UiPalette.TEXT_LIGHT)
	_bench_label.clip_text = true
	_bench_label.custom_minimum_size = Vector2(120, 0)
	right.add_child(_bench_label)
	_bench = DentBench.new()
	_bench.custom_minimum_size = Vector2(0, 262)
	_bench.struck.connect(_strike)
	_bench.turned.connect(_turn_sound)
	right.add_child(_bench)
	var turns := HBoxContainer.new()
	turns.add_theme_constant_override("separation", 10)
	right.add_child(turns)
	for i in 2:
		var button := _button(["Q. Turn Left", "E. Turn Right"][i], Vector2(124, 40), [-1.0, 1.4][i], 98 + i)
		button.font_size = 15
		button.pressed.connect(_turn.bind(TURN_DEGREES * (1.0 if i == 1 else -1.0)))
		turns.add_child(button)
		_turn_buttons.append(button)
	_side_button = _button("R. Turn Hammer", Vector2(124, 40), -0.6, 105)
	_side_button.font_size = 15
	_side_button.pressed.connect(_turn_hammer)
	turns.add_child(_side_button)
	var mirror_button := _button("T. Mirror", Vector2(124, 40), 1.1, 106)
	mirror_button.font_size = 15
	mirror_button.pressed.connect(_mirror_hammer)
	turns.add_child(mirror_button)
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
	# Wraps rather than widening the column past the board's edge.
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size = Vector2(120, 0)
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
