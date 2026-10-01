extends CanvasLayer
## The journal (autoload `Journal`): J opens a board listing the player's
## quests, pausing the game like the pause menu does; J or Esc closes it.
## Pick a quest on the left to read it, and hit Track to pin it to the
## on-screen tracker in the top-left corner.
##
## Also owns the two bits of quest HUD that show outside the journal: the
## tracker (with a live count for quests that have one), and the card that
## pops up when Quests gives a quest ("NEW QUEST") or one is done
## ("QUEST COMPLETE").
## None of it shows on menu screens, in races or during cutscenes.
##
## Built in code, like the dev menu, from the shared ScrapPanel/ScrapButton
## pieces so it matches every other board in the game.

const LAYER := 45
const MENU_SCENES_DIR := "res://scenes/menu/"
const RACE_SCENES_DIR := "res://scenes/race/"
const WORLD_SCENE := "res://scenes/world/main.tscn"
const BOARD_SIZE := Vector2(840, 470)
const LIST_WIDTH := 250.0
const TOAST_SECONDS := 3.5
## How long a card stays up when more are waiting behind it.
const TOAST_SECONDS_BUSY := 1.8
const OVERLAY_ALPHA := 0.5

var _open: bool = false

var _panel: Control
var _list: VBoxContainer
var _empty_label: Label
var _detail: VBoxContainer
var _title_label: Label
var _giver_label: Label
var _description_label: Label
var _objective_label: Label
var _reward_label: Label
var _track_button: ScrapButton
var _selected: QuestData = null

var _tracker: ScrapPanel
var _tracker_title: Label
var _tracker_objective: Label

var _toast: ScrapPanel
var _toast_header: Label
var _toast_title: Label
var _toast_hint: Label
var _toast_tween: Tween
## Cards waiting their turn, oldest first: [header, title, hint, sound,
## quest id, stale_when_done]. One
## shows at a time, and none while a character dialog is open, so a quest
## finishing and its follow-up starting show one after the other instead of
## the second wiping out the first.
var _card_queue: Array = []

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_tracker()
	_build_toast()
	_build_panel()
	Quests.quest_added.connect(_on_quest_added)
	Quests.quest_ready.connect(_on_quest_ready)
	Quests.quest_completed.connect(_on_quest_completed)
	Quests.tracked_changed.connect(func(_quest: QuestData) -> void: _refresh_tracker())
	_refresh_tracker()

func is_open() -> bool:
	return _open

func open() -> void:
	if _open or not _can_open():
		return
	_open = true
	get_tree().paused = true
	var quests := _all_quests()
	_selected = Quests.tracked
	if _selected == null and not quests.is_empty():
		_selected = quests.front()
	_rebuild_list()
	_panel.visible = true
	_pop(_panel.get_node("Board"))
	Sfx.play(&"journal_flip", -6.0, 0.05)

func close() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	get_tree().paused = false
	Sfx.play(&"journal_flip", -9.0, 0.05).pitch_scale *= 0.85

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	if _open and (key == KEY_J or key == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif not _open and key == KEY_J and _can_open():
		open()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_tracker.visible = Quests.tracked != null and not _open and hud_allowed() and _in_world() \
			and not _dialog_open()
	if _tracker.visible:
		_refresh_tracker()
	if _toast.visible and (not hud_allowed() or _dialog_open()):
		_toast.visible = false
	# A "new quest" or "objective done" card for a quest that's finished by
	# now is old news: drop it rather than show it.
	while not _card_queue.is_empty() and _card_queue[0][5] and Quests.is_complete(_card_queue[0][4]):
		_card_queue.pop_front()
	if not _toast.visible and not _card_queue.is_empty() and hud_allowed() and not _dialog_open():
		var card: Array = _card_queue.pop_front()
		_show_card(card[0], card[1], card[2], card[3])

## The world (or a building) is on screen and nothing else has the player.
func _can_open() -> bool:
	return hud_allowed() and not get_tree().paused

## The world (or a building) is on screen: not a menu, not a race, no
## cutscene. The trunk (I) uses the same rule.
func hud_allowed() -> bool:
	var scene := get_tree().current_scene
	if scene == null or Cutscenes.is_active():
		return false
	var path := scene.scene_file_path
	return not path.begins_with(MENU_SCENES_DIR) and not path.begins_with(RACE_SCENES_DIR)

## The open world itself, not a building interior: the only place the
## tracker shows.
func _in_world() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == WORLD_SCENE

func _dialog_open() -> bool:
	for dialog in get_tree().get_nodes_in_group(CharacterDialog.GROUP):
		if (dialog as CharacterDialog).is_open():
			return true
	return false

func _all_quests() -> Array[QuestData]:
	var quests: Array[QuestData] = []
	quests.append_array(Quests.active)
	quests.append_array(Quests.completed)
	return quests

# --- Journal board -------------------------------------------------------------------

func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, OVERLAY_ALPHA)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(overlay)

	var board := _make_board(UiPalette.CARDBOARD_BASE, UiPalette.CARDBOARD_SHADE, UiPalette.CARDBOARD_DARK, -1.0, 131, true)
	board.name = "Board"
	board.set_anchors_preset(Control.PRESET_CENTER)
	board.offset_left = -BOARD_SIZE.x * 0.5
	board.offset_right = BOARD_SIZE.x * 0.5
	board.offset_top = -BOARD_SIZE.y * 0.5 + 30.0
	board.offset_bottom = BOARD_SIZE.y * 0.5 + 30.0
	_panel.add_child(board)

	var title_plate := _make_board(UiPalette.SURFACE_BASE, UiPalette.SURFACE_SHADE, UiPalette.SURFACE_DARK, 1.5, 137, false)
	title_plate.position = Vector2(BOARD_SIZE.x * 0.5 - 130.0, -38.0)
	title_plate.size = Vector2(260.0, 60.0)
	board.add_child(title_plate)
	var title := _make_label("JOURNAL", 32, UiPalette.TEXT_BROWN)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_plate.add_child(title)

	var columns := HBoxContainer.new()
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 30.0
	columns.offset_top = 40.0
	columns.offset_right = -30.0
	columns.offset_bottom = -44.0
	columns.add_theme_constant_override("separation", 26)
	board.add_child(columns)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(LIST_WIDTH, 0.0)
	_list.add_theme_constant_override("separation", 10)
	columns.add_child(_list)

	var divider := ColorRect.new()
	divider.color = UiPalette.CARDBOARD_DARK
	divider.custom_minimum_size = Vector2(6.0, 0.0)
	columns.add_child(divider)

	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	columns.add_child(_detail)

	_title_label = _make_label("", 30, UiPalette.TEXT_BROWN)
	_detail.add_child(_title_label)
	_giver_label = _make_label("", 18, UiPalette.SURFACE_DARK)
	_detail.add_child(_giver_label)
	_description_label = _make_label("", 20, UiPalette.TEXT_BROWN)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(_description_label)
	_objective_label = _make_label("", 20, UiPalette.TEXT_BROWN)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_objective_label)
	_reward_label = _make_label("", 20, UiPalette.TEXT_BROWN)
	_detail.add_child(_reward_label)

	_track_button = ScrapButton.new()
	_track_button.custom_minimum_size = Vector2(170.0, 46.0)
	_track_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_track_button.font_size = 22
	_track_button.tilt_degrees = -1.5
	_track_button.jitter_seed = 141
	_track_button.pressed.connect(_on_track_pressed)
	_detail.add_child(_track_button)

	_empty_label = _make_label("No quests yet. Go talk to people.", 22, UiPalette.TEXT_BROWN)
	_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.add_child(_empty_label)

	var hint := _make_label("J / Esc  close", 16, UiPalette.SURFACE_DARK)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -200.0
	hint.offset_top = -36.0
	hint.offset_right = -24.0
	hint.offset_bottom = -12.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board.add_child(hint)

func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var quests := _all_quests()
	_empty_label.visible = quests.is_empty()
	_list.visible = not quests.is_empty()
	_detail.visible = not quests.is_empty()
	for i in quests.size():
		var quest := quests[i]
		var button := ScrapButton.new()
		var done := Quests.is_complete(quest.id)
		button.text = quest.title + (" (done)" if done else "")
		button.custom_minimum_size = Vector2(LIST_WIDTH, 46.0)
		button.font_size = 20
		button.tilt_degrees = 1.5 if i % 2 == 0 else -1.5
		button.jitter_seed = 150 + i
		button.selected = quest == _selected
		button.pressed.connect(func() -> void:
			_selected = quest
			_rebuild_list())
		_list.add_child(button)
	_show_detail()

func _show_detail() -> void:
	if _selected == null:
		return
	var done := Quests.is_complete(_selected.id)
	_title_label.text = _selected.title
	_giver_label.text = "From %s" % _selected.giver if not _selected.giver.is_empty() else ""
	_giver_label.visible = not _selected.giver.is_empty()
	_description_label.text = PlayerProfile.fill(_selected.description)
	_objective_label.text = "Done!" if done else "To do: %s" % Quests.objective_text(_selected)
	var reward := Quests.reward_text(_selected)
	_reward_label.text = "Reward: %s" % reward
	_reward_label.visible = not reward.is_empty() and not done
	_track_button.visible = not done
	var tracking := Quests.tracked == _selected
	_track_button.selected = tracking
	_track_button.text = "Tracking" if tracking else "Track"

func _on_track_pressed() -> void:
	if _selected == null:
		return
	Quests.set_tracked(null if Quests.tracked == _selected else _selected)
	_show_detail()

# --- Tracker and new-quest card ---------------------------------------------------

func _build_tracker() -> void:
	_tracker = _make_board(UiPalette.CARDBOARD_BASE, UiPalette.CARDBOARD_SHADE, UiPalette.CARDBOARD_DARK, -1.0, 161, false)
	_tracker.position = Vector2(20.0, 18.0)
	_tracker.size = Vector2(320.0, 86.0)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.visible = false
	add_child(_tracker)
	_tracker_title = _make_label("", 20, UiPalette.TEXT_BROWN)
	_tracker_title.position = Vector2(16.0, 8.0)
	_tracker_title.size = Vector2(290.0, 26.0)
	_tracker_title.clip_text = true
	_tracker.add_child(_tracker_title)
	_tracker_objective = _make_label("", 16, UiPalette.SURFACE_DARK)
	_tracker_objective.position = Vector2(16.0, 34.0)
	_tracker_objective.size = Vector2(290.0, 44.0)
	_tracker_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker.add_child(_tracker_objective)

func _refresh_tracker() -> void:
	var quest := Quests.tracked
	if quest == null:
		return
	_tracker_title.text = quest.title
	_tracker_objective.text = Quests.objective_text(quest)

func _build_toast() -> void:
	_toast = _make_board(UiPalette.SURFACE_BASE, UiPalette.SURFACE_SHADE, UiPalette.SURFACE_DARK, 1.0, 171, false)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -220.0
	_toast.offset_right = 220.0
	_toast.offset_top = 70.0
	_toast.offset_bottom = 176.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	_toast_header = _make_label("NEW QUEST", 18, UiPalette.ACCENT_YELLOW)
	_toast_header.position = Vector2(0.0, 10.0)
	_toast_header.size = Vector2(440.0, 24.0)
	_toast_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_header)
	_toast_title = _make_label("", 28, UiPalette.TEXT_LIGHT)
	_toast_title.position = Vector2(0.0, 34.0)
	_toast_title.size = Vector2(440.0, 36.0)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_title)
	_toast_hint = _make_label("", 16, UiPalette.CARDBOARD_LIGHT)
	_toast_hint.position = Vector2(0.0, 72.0)
	_toast_hint.size = Vector2(440.0, 22.0)
	_toast_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_hint)

func _on_quest_added(quest: QuestData) -> void:
	_refresh_tracker()
	var hint := "Press J to open your journal"
	if quest.start_money > 0:
		hint = "+$%d from %s   Press J for your journal" % [quest.start_money, quest.giver]
	_queue_card("NEW QUEST", quest.title, hint, &"quest_added", quest.id, true)

func _on_quest_ready(quest: QuestData) -> void:
	_refresh_tracker()
	_queue_card("OBJECTIVE DONE", quest.title, Quests.objective_text(quest), &"quest_added", quest.id, true)

func _on_quest_completed(quest: QuestData) -> void:
	_refresh_tracker()
	var reward := Quests.reward_text(quest)
	var hint := "Reward: %s" % reward if not reward.is_empty() else "Nice work."
	_queue_card("QUEST COMPLETE", quest.title, hint, &"quest_complete", quest.id, false)

func _queue_card(header: String, title: String, hint: String, sound: StringName,
		quest_id: StringName, stale_when_done: bool) -> void:
	_card_queue.append([header, title, hint, sound, quest_id, stale_when_done])

func _show_card(header: String, title: String, hint: String, sound: StringName) -> void:
	Sfx.play(sound, -4.0, 0.0)
	_toast_header.text = header
	_toast_title.text = title
	_toast_hint.text = hint
	_toast.visible = true
	_pop(_toast)
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS_BUSY if not _card_queue.is_empty() else TOAST_SECONDS)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)

# --- Helpers ---------------------------------------------------------------------------

func _make_board(body: Color, shade: Color, skirt: Color, tilt: float, seed: int, nails: bool) -> ScrapPanel:
	var board := ScrapPanel.new()
	board.body_color = body
	board.shade_color = shade
	board.skirt_color = skirt
	board.tilt_degrees = tilt
	board.jitter_seed = seed
	board.nails = nails
	return board

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## A quick squash-and-stretch as a board lands.
func _pop(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.9, 1.08)
	var tween := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.45)
