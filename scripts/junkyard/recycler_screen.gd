class_name RecyclerScreen
extends CanvasLayer
## The junkyard recycler's panel: the player's loose parts on the left
## (LoosePartsPicker, shared with the pan factory), and on the right the
## shredder and the scrap-and-cash exchange.
##
## Shredding turns a picked loose part into scrap (PartRecycling.scrap_range,
## rolled each time). It takes two presses, the first only arms it, since a
## shredded part is gone for good, and it refuses a part an active quest is
## still waiting on. The exchange sells scrap at SCRAP_PER_DOLLAR to the dollar
## (whole dollars only) and buys it back at DOLLARS_PER_SCRAP each.
##
## Everything is saved the moment it happens, so closing can't lose anything.

signal closed

const BOARD_SIZE := Vector2(1060, 610)
## 5 scrap sells for $1 (0.2 each); $1 buys 1 scrap.
const SCRAP_PER_DOLLAR := 5
const DOLLARS_PER_SCRAP := 1
## How much scrap each sell button offers (0: the whole pile), and each buy
## button buys.
const SELL_AMOUNTS := [5, 50, 0]
const BUY_AMOUNTS := [1, 10, 100]
const SHRED_TIME := 0.6
## How long the "+N SCRAP" stamp stays up after a shred, and how long the
## scrap total takes to count up to its new number.
const GAIN_HOLD := 1.6
const COUNT_UP_TIME := 0.6

@export_group("Lines")
@export var greet_line: String = "The recycler. Parts in the top, scrap out the bottom. And scrap's worth cash, if you need it: %d scrap to the dollar, a dollar a scrap back."
@export var pick_line: String = "That one? It'll come out as %d to %d scrap."
@export var arm_line: String = "Last chance. Once it's in, it's scrap."
@export var shredded_line: String = "Crunch. %d scrap, fresh off the belt."
@export var quest_line: String = "Hold on, somebody's waitin' on that one. (%s)"
@export var no_part_line: String = "Pick a part first."
@export var sold_line: String = "%d scrap, that's $%d."
@export var too_little_line: String = "Need at least %d scrap to make a dollar."
@export var bought_line: String = "%d scrap, $%d. Pleasure doin' business."
@export var broke_line: String = "That's $%d. You ain't got it."

var _part: PartData = null
var _armed := false
var _busy := false
var _rng := RandomNumberGenerator.new()

var _line_label: Label
var _picker: LoosePartsPicker
var _slot: PartSlot
var _pick_hint: Label
var _value_label: Label
var _shred_button: ScrapButton
var _sell_buttons: Array[ScrapButton] = []
var _buy_buttons: Array[ScrapButton] = []
var _stats_label: Label
var _gain_plate: ScrapPanel
var _gain_label: Label
var _gain_tween: Tween
## The scrap total the status line shows while it counts up after a shred.
var _shown_scrap := -1
var _leave_button: ScrapButton

func _ready() -> void:
	layer = 4
	_rng.randomize()
	_build()
	visible = false

func open() -> void:
	_hide_gain()
	_picker.clear_rows()
	_select(null)
	_line_label.text = greet_line % [SCRAP_PER_DOLLAR, DOLLARS_PER_SCRAP]
	_refresh()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	_select(null)
	closed.emit()

func is_open() -> bool:
	return visible

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo \
			or event.is_command_or_control_pressed():
		return
	match event.keycode:
		KEY_ESCAPE, KEY_2:
			get_viewport().set_input_as_handled()
			close()
		KEY_1:
			get_viewport().set_input_as_handled()
			_shred()

# --- Shredding -----------------------------------------------------------------

func _select(part: PartData) -> void:
	_part = part
	_armed = false
	if part != null:
		_hide_gain()
		var span := PartRecycling.scrap_range(part)
		_line_label.text = pick_line % [span.x, span.y]
		Sfx.play(&"wood_clonk", -10.0)
	_refresh()

func _shred() -> void:
	if _busy:
		return
	if _part == null:
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = no_part_line
		return
	var quest := PartRecycling.quest_needing(_part)
	if quest != null:
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = quest_line % quest.title
		return
	if not _armed:
		_armed = true
		_line_label.text = arm_line
		_refresh()
		return
	var part := _part
	var scrap := PartRecycling.roll_scrap(part, _rng)
	var scrap_before := Inventory.scrap
	Inventory.take_spare(part)
	Inventory.add_scrap(scrap)
	SaveSystem.save_game()
	_busy = true
	Sfx.play(&"shredder_grind", -4.0)
	var tween := create_tween()
	_slot.pivot_offset = _slot.size / 2.0
	tween.tween_property(_slot, "rotation", deg_to_rad(8.0), SHRED_TIME * 0.25)
	tween.parallel().tween_property(_slot, "scale", Vector2(0.6, 0.3), SHRED_TIME * 0.5)
	tween.tween_property(_slot, "scale", Vector2(0.0, 0.0), SHRED_TIME * 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_slot.rotation = 0.0
		_slot.scale = Vector2.ONE
		_busy = false
		_picker.drop_row(part.id)
		_shown_scrap = scrap_before
		_select(null)
		_line_label.text = shredded_line % scrap
		_show_gain(scrap, scrap_before)
		Sfx.play(&"scrap_pickup", -6.0))

## Stamps a big "+N SCRAP" where the part was and counts the scrap total up
## from `scrap_before`.
func _show_gain(scrap: int, scrap_before: int) -> void:
	_gain_label.text = "+%d SCRAP" % scrap
	_pick_hint.visible = false
	_gain_plate.visible = true
	_gain_plate.pivot_offset = _gain_plate.size / 2.0
	_gain_plate.scale = Vector2(0.2, 0.2)
	if _gain_tween != null:
		_gain_tween.kill()
	_gain_tween = create_tween()
	_gain_tween.tween_property(_gain_plate, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_gain_tween.parallel().tween_method(_show_scrap_count, scrap_before, Inventory.scrap, COUNT_UP_TIME).set_delay(0.15)
	_gain_tween.tween_interval(GAIN_HOLD)
	_gain_tween.tween_property(_gain_plate, "scale", Vector2(0.0, 0.0), 0.15).set_ease(Tween.EASE_IN)
	_gain_tween.tween_callback(func() -> void:
		_gain_plate.visible = false
		_shown_scrap = -1
		_refresh())

func _hide_gain() -> void:
	if _gain_tween != null:
		_gain_tween.kill()
	_gain_plate.visible = false
	_shown_scrap = -1

func _show_scrap_count(count: int) -> void:
	_shown_scrap = count
	_stats_label.text = "You have %d scrap and $%d." % [count, Inventory.money]

# --- Exchange ------------------------------------------------------------------

## Sells up to `amount` scrap (0: the whole pile).
func _sell(amount: int) -> void:
	var offered := Inventory.scrap if amount <= 0 else amount
	if offered < SCRAP_PER_DOLLAR or Inventory.scrap < SCRAP_PER_DOLLAR:
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = too_little_line % SCRAP_PER_DOLLAR
		return
	var dollars := Inventory.sell_scrap(offered, SCRAP_PER_DOLLAR)
	Sfx.play(&"cash_register", -4.0, 0.0)
	_line_label.text = sold_line % [dollars * SCRAP_PER_DOLLAR, dollars]
	SaveSystem.save_game()
	_refresh()

func _buy(amount: int) -> void:
	var price := amount * DOLLARS_PER_SCRAP
	if not Inventory.buy_scrap(amount, DOLLARS_PER_SCRAP):
		Sfx.play(&"denied", -6.0, 0.0)
		_line_label.text = broke_line % price
		return
	Sfx.play(&"scrap_pickup", -6.0)
	_line_label.text = bought_line % [amount, price]
	SaveSystem.save_game()
	_refresh()

# --- Refreshing ----------------------------------------------------------------

func _refresh() -> void:
	_picker.pinned = _part
	_picker.refresh()
	_slot.visible = _part != null
	_pick_hint.visible = _part == null and not _gain_plate.visible
	if _part != null:
		_slot.set_part(_part)
		var span := PartRecycling.scrap_range(_part)
		_value_label.text = "Shreds down to %d-%d scrap." % [span.x, span.y]
	else:
		_value_label.text = ""
	_shred_button.text = "1. Really? Shred It" if _armed else "1. Shred It"
	_shred_button.selected = _armed
	_shred_button.disabled = _part == null or _busy
	for i in SELL_AMOUNTS.size():
		var amount: int = SELL_AMOUNTS[i]
		var offered := Inventory.scrap if amount <= 0 else amount
		var dollars := mini(offered, Inventory.scrap) / SCRAP_PER_DOLLAR
		_sell_buttons[i].text = ("Sell All: $%d" % dollars) if amount <= 0 else ("Sell %d: $%d" % [amount, amount / SCRAP_PER_DOLLAR])
		_sell_buttons[i].disabled = dollars <= 0 or (amount > 0 and Inventory.scrap < amount)
	for i in BUY_AMOUNTS.size():
		var amount: int = BUY_AMOUNTS[i]
		_buy_buttons[i].text = "Buy %d: $%d" % [amount, amount * DOLLARS_PER_SCRAP]
		_buy_buttons[i].disabled = not Inventory.can_afford(amount * DOLLARS_PER_SCRAP)
	_stats_label.text = "You have %d scrap and $%d." % [
		_shown_scrap if _shown_scrap >= 0 else Inventory.scrap, Inventory.money]

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
	board.tilt_degrees = -0.5
	board.jitter_seed = 121
	backdrop.add_child(board)

	var plate := ScrapPanel.new()
	plate.body_color = UiPalette.ACCENT_YELLOW
	plate.shade_color = UiPalette.ACCENT_YELLOW.darkened(0.15)
	plate.skirt_color = UiPalette.ACCENT_YELLOW.darkened(0.3)
	plate.nails = false
	plate.tilt_degrees = 1.2
	plate.jitter_seed = 122
	plate.position = Vector2(24, -22)
	plate.size = Vector2(250, 50)
	board.add_child(plate)
	var title := _label("RECYCLER", 28, UiPalette.INK)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(title)

	_line_label = _label("", 18, UiPalette.TEXT_LIGHT)
	_line_label.position = Vector2(300, 14)
	_line_label.size = Vector2(BOARD_SIZE.x - 330, 64)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.add_child(_line_label)

	_picker = LoosePartsPicker.new()
	_picker.title = "LOOSE PARTS (click to pick)"
	_picker.seed_base = 131
	_picker.position = Vector2(26, 82)
	_picker.size = Vector2(440, BOARD_SIZE.y - 112)
	_picker.part_picked.connect(_select)
	board.add_child(_picker)

	var right := VBoxContainer.new()
	right.position = Vector2(496, 88)
	right.size = Vector2(BOARD_SIZE.x - 526, BOARD_SIZE.y - 110)
	right.add_theme_constant_override("separation", 10)
	board.add_child(right)
	right.add_child(_label("SHREDDER", 16, UiPalette.TEXT_LIGHT))
	var slot_holder := Control.new()
	slot_holder.custom_minimum_size = Vector2(0, 104)
	right.add_child(slot_holder)
	_slot = (load("res://scenes/garage/part_slot.tscn") as PackedScene).instantiate()
	_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_holder.add_child(_slot)
	_pick_hint = _label("Pick a part on the left to shred it.", 18, UiPalette.TEXT_LIGHT)
	_pick_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pick_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_holder.add_child(_pick_hint)
	_gain_plate = ScrapPanel.new()
	_gain_plate.body_color = UiPalette.ACCENT_YELLOW
	_gain_plate.shade_color = UiPalette.ACCENT_YELLOW.darkened(0.15)
	_gain_plate.skirt_color = UiPalette.ACCENT_YELLOW.darkened(0.3)
	_gain_plate.nails = false
	_gain_plate.tilt_degrees = -3.0
	_gain_plate.jitter_seed = 132
	_gain_plate.size = Vector2(300, 80)
	_gain_plate.position = Vector2(110, 12)
	_gain_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gain_plate.visible = false
	slot_holder.add_child(_gain_plate)
	_gain_label = _label("", 40, UiPalette.INK)
	_gain_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gain_plate.add_child(_gain_label)
	var shred_row := HBoxContainer.new()
	shred_row.add_theme_constant_override("separation", 14)
	right.add_child(shred_row)
	_shred_button = _button("1. Shred It", Vector2(230, 46), 1.4, 123)
	_shred_button.pressed.connect(_shred)
	shred_row.add_child(_shred_button)
	_value_label = _label("", 17, UiPalette.TEXT_LIGHT)
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.size_flags_vertical = Control.SIZE_FILL
	shred_row.add_child(_value_label)

	var stripe := HazardStripe.new()
	stripe.custom_minimum_size = Vector2(0, 10)
	right.add_child(stripe)
	right.add_child(_label("SCRAP AND CASH  (%d scrap = $1, $%d = 1 scrap)" % [SCRAP_PER_DOLLAR, DOLLARS_PER_SCRAP], 16, UiPalette.TEXT_LIGHT))
	var sell_row := HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 10)
	right.add_child(sell_row)
	for i in SELL_AMOUNTS.size():
		var button := _button("", Vector2(168, 44), [-1.0, 0.8, -1.4][i], 124 + i)
		button.font_size = 17
		button.pressed.connect(_sell.bind(SELL_AMOUNTS[i]))
		sell_row.add_child(button)
		_sell_buttons.append(button)
	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 10)
	right.add_child(buy_row)
	for i in BUY_AMOUNTS.size():
		var button := _button("", Vector2(168, 44), [1.2, -0.6, 1.0][i], 127 + i)
		button.font_size = 17
		button.pressed.connect(_buy.bind(BUY_AMOUNTS[i]))
		buy_row.add_child(button)
		_buy_buttons.append(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	right.add_child(bottom)
	_stats_label = _label("", 16, UiPalette.TEXT_LIGHT)
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size = Vector2(120, 0)
	bottom.add_child(_stats_label)
	_leave_button = _button("2. Walk Away", Vector2(190, 46), -1.2, 130)
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
