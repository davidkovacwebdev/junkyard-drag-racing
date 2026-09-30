extends CanvasLayer
## Developer quest board (autoload `QuestDebugger`): F5 lists every quest
## under res://quests with where it stands, so any one can be tried without
## playing up to it.
##
##   Give       - hands the quest over right now and tracks it (skipping its
##                start cutscene).
##   Finish     - completes it on the spot: pays its reward, hands out its
##                follow-ups and unlocks, exactly like finishing it for real.
##   Reset all  - empties the quest log.
##
## Debug builds only, like the F1 dev menu. Pauses the game while open; F5 or
## Esc closes. Steel board with off-white text, the dev-tool look.

const LAYER := 47
const QUESTS_ROOT := "res://quests"
const BOARD_SIZE := Vector2(820.0, 500.0)
const ROW_HEIGHT := 44.0
const OVERLAY_ALPHA := 0.55

var _enabled: bool = false
var _open: bool = false
var _quests: Array[QuestData] = []

var _root: Control
var _rows: VBoxContainer

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = OS.is_debug_build()
	_build()

func _input(event: InputEvent) -> void:
	if not _enabled or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	if _open and (key == KEY_F5 or key == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif not _open and key == KEY_F5 and not get_tree().paused and not Cutscenes.is_active():
		open()
		get_viewport().set_input_as_handled()

func open() -> void:
	_open = true
	get_tree().paused = true
	_quests = _load_quests()
	_refresh()
	_root.visible = true

func close() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false

## Every QuestData .tres under res://quests (subfolders too), by title.
func _load_quests() -> Array[QuestData]:
	var found: Array[QuestData] = []
	var dirs := PackedStringArray([QUESTS_ROOT])
	var index := 0
	while index < dirs.size():
		var dir := dirs[index]
		index += 1
		for entry in ResourceLoader.list_directory(dir):
			if entry.ends_with("/"):
				dirs.append(dir.path_join(entry.trim_suffix("/")))
			elif entry.ends_with(".tres"):
				var quest := load(dir.path_join(entry)) as QuestData
				if quest != null:
					found.append(quest)
	found.sort_custom(func(a: QuestData, b: QuestData) -> bool: return a.title < b.title)
	return found

func _state_of(quest: QuestData) -> String:
	if Quests.is_complete(quest.id):
		return "done"
	if Quests.is_ready(quest.id):
		return "ready to hand in"
	if Quests.has_quest(quest.id):
		return "tracked" if Quests.tracked == quest else "active"
	if not Quests.available_from(quest.giver).filter(func(q: QuestData) -> bool: return q.id == quest.id).is_empty():
		return "available"
	return "not started"

func _on_give(quest: QuestData) -> void:
	Quests.give(quest)
	Quests.set_tracked(quest)
	_refresh()

func _on_finish(quest: QuestData) -> void:
	if not Quests.has_quest(quest.id):
		Quests.give(quest)
	Quests.complete(quest.id)
	_refresh()

func _on_reset() -> void:
	Quests.reset()
	_refresh()

# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, OVERLAY_ALPHA)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)

	var board := ScrapPanel.new()
	board.body_color = UiPalette.STEEL_DARK
	board.shade_color = UiPalette.METAL_GREY
	board.skirt_color = UiPalette.INK
	board.tilt_degrees = -0.6
	board.jitter_seed = 331
	board.set_anchors_preset(Control.PRESET_CENTER)
	board.offset_left = -BOARD_SIZE.x * 0.5
	board.offset_right = BOARD_SIZE.x * 0.5
	board.offset_top = -BOARD_SIZE.y * 0.5
	board.offset_bottom = BOARD_SIZE.y * 0.5
	_root.add_child(board)

	var title := _make_label("QUEST DEBUG", 28, UiPalette.ACCENT_YELLOW)
	title.position = Vector2(28.0, 16.0)
	board.add_child(title)
	var hint := _make_label("F5 / Esc  close", 16, UiPalette.STEEL_LIGHT)
	hint.position = Vector2(BOARD_SIZE.x - 170.0, 24.0)
	board.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24.0, 64.0)
	scroll.size = Vector2(BOARD_SIZE.x - 48.0, BOARD_SIZE.y - 140.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

	var reset := _make_button("Reset all quests", 200.0, 7)
	reset.position = Vector2(24.0, BOARD_SIZE.y - 64.0)
	reset.pressed.connect(_on_reset)
	board.add_child(reset)

func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for i in _quests.size():
		_rows.add_child(_build_row(_quests[i], i))

func _build_row(quest: QuestData, index: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 12)

	var name_label := _make_label("%s  (%s)" % [quest.title, quest.id], 18, UiPalette.TEXT_LIGHT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	row.add_child(name_label)

	var state := _state_of(quest)
	var state_label := _make_label(state, 16, UiPalette.ACCENT_YELLOW if state != "not started" else UiPalette.STEEL_LIGHT)
	state_label.custom_minimum_size = Vector2(150.0, 0.0)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(state_label)

	var give := _make_button("Give", 90.0, index * 2)
	give.disabled = Quests.has_quest(quest.id) or Quests.is_complete(quest.id)
	give.pressed.connect(_on_give.bind(quest))
	row.add_child(give)

	var finish := _make_button("Finish", 100.0, index * 2 + 1)
	finish.disabled = Quests.is_complete(quest.id)
	finish.pressed.connect(_on_finish.bind(quest))
	row.add_child(finish)
	return row

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_button(text: String, width: float, seed_offset: int) -> ScrapButton:
	var button := ScrapButton.new()
	button.text = text
	button.font_size = 18
	button.custom_minimum_size = Vector2(width, ROW_HEIGHT - 6.0)
	button.size = button.custom_minimum_size
	button.tilt_degrees = 1.2 if seed_offset % 2 == 0 else -1.2
	button.jitter_seed = 400 + seed_offset
	return button
