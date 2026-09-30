extends CanvasLayer
## The trunk (autoload `Trunk`): I pops the car's trunk open to show the
## things the player carries that aren't car parts: quest items, gadgets,
## anything bought at the shop (Inventory.owned_items). Six spaces, filled
## in the order things were picked up. Hover a space to read what's in it.
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

var _open: bool = false

var _root: Control
var _panel: TrunkPanel
var _slots: Array[TrunkSlot] = []
var _info_name: Label
var _info_text: Label

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
	get_tree().paused = false
	Sfx.play(&"trunk_close", -5.0, 0.04)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	if _open and (key == KEY_I or key == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif not _open and key == KEY_I and _can_open():
		open()
		get_viewport().set_input_as_handled()

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
	hint.text = "I / Esc  close"
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.offset_left = -PANEL_SIZE.x * 0.5 + 34.0
	hint.offset_right = -PANEL_SIZE.x * 0.5 + 234.0
	hint.offset_top = PANEL_SIZE.y * 0.5 + 86.0
	hint.offset_bottom = PANEL_SIZE.y * 0.5 + 110.0
	_root.add_child(hint)

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
