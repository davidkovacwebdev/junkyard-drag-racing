extends CanvasLayer
## The trunk (autoload `Trunk`): I pops the car's trunk open to show the
## things the player carries that aren't car parts: quest items, gadgets,
## anything bought at the shop (Inventory.owned_items). Six spaces, filled
## in the order things were picked up. Hover a space to read what's in it.
##
## Some things can be used (a six-pack's cans; see ItemData.uses), or used
## over and over (the fishing rod; ItemData.reusable): press the space's
## number (1-6) or double-click it. Something used out in the world shuts the
## trunk (ItemData.closes_trunk). The space shows the uses left,
## and Inventory.item_used tells whoever cares (Drunk, for beer).
##
## Something to read (ItemData.read_text, Grandpa's note) opens on a sheet
## of paper over the trunk when used; any key or a click puts it away again.
##
## Pauses the game like the journal and the pause menu; I or Esc closes it.
## Only opens where the journal can (world and buildings, no cutscene).

const LAYER := 46
const PANEL_SIZE := Vector2(660.0, 420.0)
const COLUMNS := 3
const SLOT_GAP := Vector2(18.0, 16.0)
const OVERLAY_ALPHA := 0.5
const EMPTY_HINT := "Hover something to look at it."
const NOTHING_HINT := "Nothing in here yet but an old spare tire smell."
const CANT_USE_LINE := "You can't use the %s like that."
const USE_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const PAPER_SIZE := Vector2(760.0, 560.0)

var _open: bool = false

var _root: Control
var _panel: TrunkPanel
var _slots: Array[TrunkSlot] = []
var _info_name: Label
var _info_text: Label
## The sheet a readable item opens on (see `_read()`).
var _paper: Control
var _paper_title: Label
var _paper_text: Label

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func is_open() -> bool:
	return _open

func open() -> void:
	if _open or not _can_open():
		return
	_open = true
	get_tree().paused = true
	_fill_slots()
	_show_info(null)
	_root.visible = true
	_pop(_panel)
	Sfx.play(&"trunk_open", -5.0, 0.04)

func close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	_paper.visible = false
	get_tree().paused = false
	Sfx.play(&"trunk_close", -5.0, 0.04)

func _input(event: InputEvent) -> void:
	if _open and _paper.visible:
		# Any key or click folds the paper away, back to the trunk.
		var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
		var clicked: bool = event is InputEventMouseButton and event.pressed
		if pressed_key or clicked:
			_put_paper_away()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	if _open and USE_KEYS.has(key):
		use_slot(USE_KEYS.find(key))
		get_viewport().set_input_as_handled()
	elif _open and (key == KEY_I or key == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif not _open and key == KEY_I and _can_open():
		open()
		get_viewport().set_input_as_handled()

## Uses whatever's in space `index` (0-based): a sound and its use line on
## the info board, or `denied` when there's nothing usable there.
func use_slot(index: int) -> void:
	if index < 0 or index >= _slots.size() or _slots[index].item == null:
		return
	var item := _slots[index].item
	var blocked := Inventory.use_blocked_reason(item) if Inventory.can_use(item) else CANT_USE_LINE % item.display_name
	if not blocked.is_empty() or not Inventory.use_item(item):
		Sfx.play(&"denied", -6.0, 0.0)
		_info_name.text = item.display_name
		_info_text.text = blocked
		return
	if not item.use_sound.is_empty():
		Sfx.play(item.use_sound, -4.0, 0.05)
	if not item.read_text.is_empty():
		_read(item)
		return
	if item.closes_trunk:
		close()
		return
	_fill_slots()
	_info_name.text = item.display_name
	_info_text.text = item.use_line.replace("{left}", str(Inventory.uses_left(item)))

func _can_open() -> bool:
	return Journal.hud_allowed() and not get_tree().paused

func _fill_slots() -> void:
	var items := Inventory.owned_items
	for i in _slots.size():
		_slots[i].item = items[i] if i < items.size() else null

func _show_info(item: ItemData) -> void:
	if item != null:
		_info_name.text = item.display_name
		_info_text.text = item.description
	else:
		_info_name.text = "TRUNK"
		_info_text.text = EMPTY_HINT if not Inventory.owned_items.is_empty() else NOTHING_HINT

# --- Building ------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, OVERLAY_ALPHA)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)

	_panel = TrunkPanel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_SIZE.x * 0.5
	_panel.offset_right = PANEL_SIZE.x * 0.5
	_panel.offset_top = -PANEL_SIZE.y * 0.5 - 40.0
	_panel.offset_bottom = PANEL_SIZE.y * 0.5 - 40.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	var opening := Rect2(TrunkPanel.OPENING.position * PANEL_SIZE, TrunkPanel.OPENING.size * PANEL_SIZE)
	var rows := ceili(float(Inventory.ITEM_SLOTS) / COLUMNS)
	var slot_size := (opening.size - SLOT_GAP * Vector2(COLUMNS + 1, rows + 1)) / Vector2(COLUMNS, rows)
	for i in Inventory.ITEM_SLOTS:
		var slot := TrunkSlot.new()
		var cell := Vector2(i % COLUMNS, i / COLUMNS)
		slot.position = opening.position + SLOT_GAP + cell * (slot_size + SLOT_GAP)
		slot.size = slot_size
		slot.hovered.connect(func(s: TrunkSlot) -> void: _show_info(s.item))
		slot.unhovered.connect(func(_s: TrunkSlot) -> void: _show_info(null))
		slot.activated.connect(func(s: TrunkSlot) -> void: use_slot(_slots.find(s)))
		_panel.add_child(slot)
		_slots.append(slot)

	var info := ScrapPanel.new()
	info.body_color = UiPalette.CARDBOARD_BASE
	info.shade_color = UiPalette.CARDBOARD_SHADE
	info.skirt_color = UiPalette.CARDBOARD_DARK
	info.tilt_degrees = 0.8
	info.jitter_seed = 223
	info.nails = false
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.set_anchors_preset(Control.PRESET_CENTER)
	info.offset_left = -PANEL_SIZE.x * 0.5 + 30.0
	info.offset_right = PANEL_SIZE.x * 0.5 - 30.0
	info.offset_top = PANEL_SIZE.y * 0.5 - 20.0
	info.offset_bottom = PANEL_SIZE.y * 0.5 + 80.0
	_root.add_child(info)

	_info_name = _make_label(24, UiPalette.TEXT_BROWN)
	_info_name.position = Vector2(20.0, 10.0)
	_info_name.size = Vector2(PANEL_SIZE.x - 100.0, 30.0)
	info.add_child(_info_name)
	_info_text = _make_label(18, UiPalette.SURFACE_DARK)
	_info_text.position = Vector2(20.0, 40.0)
	_info_text.size = Vector2(PANEL_SIZE.x - 100.0, 50.0)
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_info_text)

	var hint := _make_label(16, UiPalette.CARDBOARD_LIGHT)
	hint.text = "1-6 / double-click  use      I / Esc  close"
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.offset_left = -PANEL_SIZE.x * 0.5 + 34.0
	hint.offset_right = PANEL_SIZE.x * 0.5 - 34.0
	hint.offset_top = PANEL_SIZE.y * 0.5 + 86.0
	hint.offset_bottom = PANEL_SIZE.y * 0.5 + 110.0
	_root.add_child(hint)
	_build_paper()

## Opens `item`'s text on the sheet of paper, and hands out the quest it
## leads to the first time.
func _read(item: ItemData) -> void:
	_paper_title.text = item.display_name.to_upper()
	_paper_text.text = PlayerProfile.fill(item.read_text)
	_paper.visible = true
	_pop(_paper)
	Quests.item_read(item)
	if item.read_gives_quest != null:
		Quests.give(item.read_gives_quest)

func _put_paper_away() -> void:
	_paper.visible = false
	Sfx.play(&"paper_unfold", -8.0, 0.0).pitch_scale = 0.8

func _build_paper() -> void:
	var paper := ScrapPanel.new()
	paper.body_color = UiPalette.CARDBOARD_LIGHT
	paper.shade_color = UiPalette.CARDBOARD_BASE
	paper.skirt_color = UiPalette.CARDBOARD_SHADE
	paper.tilt_degrees = -1.2
	paper.jitter_seed = 431
	paper.nails = false
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.offset_left = -PAPER_SIZE.x * 0.5
	paper.offset_right = PAPER_SIZE.x * 0.5
	paper.offset_top = -PAPER_SIZE.y * 0.5 - 20.0
	paper.offset_bottom = PAPER_SIZE.y * 0.5 - 20.0
	paper.visible = false
	# Over the trunk's item icons, which sit on raised z layers of their own.
	paper.z_index = 20
	_root.add_child(paper)
	_paper = paper

	_paper_title = _make_label(26, UiPalette.TEXT_BROWN)
	_paper_title.position = Vector2(36.0, 22.0)
	_paper_title.size = Vector2(PAPER_SIZE.x - 72.0, 34.0)
	paper.add_child(_paper_title)
	_paper_text = _make_label(19, UiPalette.TEXT_BROWN)
	_paper_text.position = Vector2(36.0, 66.0)
	_paper_text.size = Vector2(PAPER_SIZE.x - 72.0, PAPER_SIZE.y - 110.0)
	_paper_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper.add_child(_paper_text)
	var hint := _make_label(15, UiPalette.SURFACE_SHADE)
	hint.text = "Any key  put it away"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(36.0, PAPER_SIZE.y - 40.0)
	hint.size = Vector2(PAPER_SIZE.x - 72.0, 24.0)
	paper.add_child(hint)

func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## The lid bounces as it swings up.
func _pop(control: Control) -> void:
	control.pivot_offset = Vector2(control.size.x * 0.5, control.size.y)
	control.scale = Vector2(1.04, 0.9)
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.5)
