@tool
extends VBoxContainer
## The Character Creator dock UI. Pick a part per slot (torso, legs,
## boots, head, hair, eyes, accessory), watch it assemble live in the
## preview, then save the loadout to res://characters/*.tres.
##
## Built entirely in code rather than as a .tscn so the dock stays a
## single self-contained script — the plugin just drops it into place.

## Kept small on purpose: the editor's side dock is narrow, and a preview
## wider than the dock forces the whole column to that width, which clips
## the rightmost buttons off the edge. PREVIEW_SCALE draws the same
## character-space geometry into a smaller box.
const PREVIEW_SIZE := Vector2(240, 320)
const PREVIEW_SCALE := 0.8
const GROUND_Y := 268.0

var _name_edit: LineEdit
var _slot_options: Dictionary = {}   # CharacterPartData.Slot -> OptionButton
var _load_option: OptionButton
var _status_label: Label
var _current_file_label: Label

var _parts_by_slot: Dictionary = {}  # CharacterPartData.Slot -> Array[Dictionary]

var _preview_viewport: SubViewport
var _preview_root: Node2D
var _preview_character: Node2D

var _character: CharacterData

## res:// path this character was loaded from or last saved to. Empty means
## it has never been written, so there is nothing for Update to overwrite.
var _current_path: String = ""

func _ready() -> void:
	_build_ui()
	_refresh_parts()
	_refresh_load_list()
	new_character()
	_connect_filesystem()

# --------------------------------------------------------------------------
# UI construction
# --------------------------------------------------------------------------

func _build_ui() -> void:
	# Everything lives inside a scroll so no control can end up stranded
	# below the fold when the dock is short.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var title_row := HBoxContainer.new()
	var title := Label.new()
	title.text = "Character Creator"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var rescan := _make_button("⟳", _on_rescan_pressed)
	rescan.tooltip_text = "Re-scan res://scenes/characters/parts for newly added parts"
	title_row.add_child(rescan)
	content.add_child(title_row)

	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(70, 0)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "Character name"
	_name_edit.text_changed.connect(func(_text: String) -> void:
		if _character != null:
			_character.display_name = _name_edit.text
	)
	name_row.add_child(_name_edit)
	content.add_child(name_row)

	# Above the preview, so Save/Update are visible without scrolling.
	# HFlowContainer wraps to a second line instead of clipping the
	# rightmost button when the dock is too narrow for one row.
	var action_row := HFlowContainer.new()
	action_row.add_child(_make_button("New", new_character))
	action_row.add_child(_make_button("Randomize", randomize_character))
	var save_as := _make_button("Save As", save_character)
	save_as.tooltip_text = "Write the character to a file named after the Name field"
	action_row.add_child(save_as)
	var update := _make_button("Update", update_character)
	update.tooltip_text = "Overwrite the file this character was loaded from"
	action_row.add_child(update)
	content.add_child(action_row)

	var load_row := HBoxContainer.new()
	_load_option = OptionButton.new()
	_load_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_row.add_child(_load_option)
	load_row.add_child(_make_button("Load", load_selected_character))
	content.add_child(load_row)

	# Which file Update will hit, so it's never a guess.
	_current_file_label = Label.new()
	_current_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_current_file_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	content.add_child(_build_preview())

	# Slot pickers take whatever vertical room is left.
	var slot_box := VBoxContainer.new()
	slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(slot_box)
	for slot in CharacterPartData.Slot.values():
		slot_box.add_child(_build_slot_row(slot))

func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = false
	container.custom_minimum_size = PREVIEW_SIZE
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(PREVIEW_SIZE)
	_preview_viewport.disable_3d = true
	_preview_viewport.transparent_bg = false
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_preview_viewport)

	var back := ColorRect.new()
	back.color = Color(0.13, 0.14, 0.17)
	back.size = PREVIEW_SIZE
	_preview_viewport.add_child(back)

	var ground := ColorRect.new()
	ground.color = Color(0.36, 0.39, 0.44)
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(PREVIEW_SIZE.x, 3)
	_preview_viewport.add_child(ground)

	# Character space has its origin at the feet, so parking this node on
	# the ground line makes every assembled character stand on it. The
	# scale maps character-space units into the smaller preview box.
	_preview_root = Node2D.new()
	_preview_root.position = Vector2(PREVIEW_SIZE.x * 0.5, GROUND_Y)
	_preview_root.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_preview_viewport.add_child(_preview_root)
	return container

func _build_slot_row(slot: int) -> Control:
	var row := HBoxContainer.new()

	# Names the slot, so seven bare dropdowns aren't a guessing game.
	var label := Label.new()
	label.text = CharacterPartData.slot_name(slot)
	label.custom_minimum_size = Vector2(70, 0)
	row.add_child(label)

	# Left empty on purpose: _populate_slot_option() fills it, so parts
	# added while the editor is open show up without a restart.
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_item("None")
	for entry in _parts_by_slot.get(slot, []):
		option.add_item(String(entry.data.display_name))
		option.set_item_metadata(option.item_count - 1, entry.scene)
	option.item_selected.connect(func(_index: int) -> void:
		_pull_ui_into_character()
		_refresh_preview()
	)
	_slot_options[slot] = option
	row.add_child(option)
	return row

func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	return button

# --------------------------------------------------------------------------
# Part list refresh
# --------------------------------------------------------------------------

## Re-reads the parts folders and refills every slot dropdown, keeping each
## dropdown's current pick when that part still exists.
func _refresh_parts() -> void:
	_parts_by_slot = CharacterDatabase.scan_parts()
	for slot in _slot_options:
		_populate_slot_option(slot, _slot_options[slot])

func _populate_slot_option(slot: int, option: OptionButton) -> void:
	var previous: Variant = null
	if option.selected >= 0 and option.selected < option.item_count:
		previous = option.get_item_metadata(option.selected)
	option.clear()
	option.add_item("None")
	for entry in _parts_by_slot.get(slot, []):
		option.add_item(String(entry.data.display_name))
		option.set_item_metadata(option.item_count - 1, entry.scene)
	option.select(_find_option_for_scene(option, previous))

## Parts are plain .tscn files, so any filesystem change could mean a new
## one was dropped in. Watching the editor's filesystem keeps the dropdowns
## current on their own; the title-bar button is the manual fallback.
func _connect_filesystem() -> void:
	if not Engine.is_editor_hint():
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem != null and not filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		filesystem.filesystem_changed.connect(_on_filesystem_changed)

func _on_filesystem_changed() -> void:
	_refresh_parts()
	_refresh_load_list()

func _on_rescan_pressed() -> void:
	_scan_filesystem()
	_refresh_parts()
	_refresh_load_list()
	_set_status("Re-scanned parts — %d found." % _count_parts())

# --------------------------------------------------------------------------
# Character <-> UI sync
# --------------------------------------------------------------------------

func new_character() -> void:
	_character = CharacterData.new()
	_character.display_name = "New Character"
	_current_path = ""
	_update_current_file_label()
	_sync_ui_from_character()
	_set_status("Started a new character.")

func randomize_character() -> void:
	if _character == null:
		new_character()
	for slot in _slot_options:
		var entries: Array = _parts_by_slot.get(slot, [])
		if entries.is_empty():
			continue
		# Optional slots sometimes stay empty so random characters vary in
		# how busy they look, not just which parts they wear.
		var optional: bool = slot == CharacterPartData.Slot.HAIR \
			or slot == CharacterPartData.Slot.EYES \
			or slot == CharacterPartData.Slot.ACCESSORY
		if optional and randf() < 0.25:
			_character.set_part(slot, null)
		else:
			_character.set_part(slot, entries[randi() % entries.size()].scene)
	_sync_ui_from_character()
	_set_status("Rolled a random character.")

func save_character() -> void:
	# "Save As": the path comes from the Name field, so renaming the
	# character writes a brand new file and leaves the original alone.
	if _character == null:
		return
	var character_name := _name_edit.text.strip_edges()
	if character_name.is_empty():
		_set_status("Give the character a name first.", true)
		return
	var path := "%s/%s.tres" % [CharacterDatabase.CHARACTERS_ROOT, _to_file_name(character_name)]
	_write_character(path, "Saved")

func update_character() -> void:
	# "Update": overwrite the file this character came from, so iterating
	# on a saved character doesn't mean retyping its name every time.
	if _character == null:
		return
	if _current_path.is_empty():
		_set_status("Nothing to update yet — use Save As the first time.", true)
		return
	if not ResourceLoader.exists(_current_path):
		_set_status("File is gone: %s — use Save As." % _current_path, true)
		_update_current_file_label()
		return
	_write_character(_current_path, "Updated")

func _write_character(path: String, verb: String) -> void:
	_pull_ui_into_character()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CharacterDatabase.CHARACTERS_ROOT))
	var error := ResourceSaver.save(_character, path)
	if error != OK:
		_set_status("%s failed (error %d)." % [verb, error], true)
		return
	_current_path = path
	_update_current_file_label()
	_scan_filesystem()
	_refresh_load_list()
	_sync_ui_from_character()
	_set_status("%s %s" % [verb, path])

## Shows which file Update will overwrite, so it is never a guess.
func _update_current_file_label() -> void:
	if _current_file_label == null:
		return
	if _current_path.is_empty():
		_current_file_label.text = "Not saved yet — use Save As to create a file."
		_current_file_label.modulate = Color(1.0, 0.85, 0.45)
	else:
		_current_file_label.text = "Update target: %s" % _current_path
		_current_file_label.modulate = Color(0.65, 0.88, 0.65)

func load_selected_character() -> void:
	if _load_option == null or _load_option.selected <= 0:
		_set_status("Pick a saved character from the dropdown first.", true)
		return
	var path := String(_load_option.get_item_metadata(_load_option.selected))
	if path.is_empty():
		_set_status("Pick a saved character from the dropdown first.", true)
		return
	if not ResourceLoader.exists(path):
		_set_status("Character file is missing: %s" % path, true)
		_refresh_load_list()
		return
	var resource := ResourceLoader.load(path)
	if not (resource is CharacterData):
		_set_status("Not a CharacterData: %s" % path, true)
		return
	_character = resource as CharacterData
	_current_path = path
	_update_current_file_label()
	_sync_ui_from_character()
	_set_status("Loaded %s" % path)

func _sync_ui_from_character() -> void:
	if _character == null:
		return
	_name_edit.text = _character.display_name
	for slot in _slot_options:
		var option: OptionButton = _slot_options[slot]
		option.selected = _find_option_for_scene(option, _character.get_part(slot))
	_refresh_preview()

func _pull_ui_into_character() -> void:
	if _character == null:
		return
	_character.display_name = _name_edit.text
	for slot in _slot_options:
		var option: OptionButton = _slot_options[slot]
		_character.set_part(slot, option.get_item_metadata(option.selected) as PackedScene)

static func _find_option_for_scene(option: OptionButton, scene: Variant) -> int:
	if scene == null:
		return 0
	# Match by resource path, not object identity: a PackedScene read back
	# from a saved .tres is not necessarily the same instance the parts
	# scan cached, but the path always is. Without this, loading a saved
	# character leaves every dropdown showing "None".
	var wanted := (scene as Resource).resource_path
	for i in option.item_count:
		var candidate: Variant = option.get_item_metadata(i)
		if candidate == null:
			continue
		if candidate == scene:
			return i
		if wanted != "" and (candidate as Resource).resource_path == wanted:
			return i
	return 0

func _count_parts() -> int:
	var total := 0
	for slot in _parts_by_slot:
		total += (_parts_by_slot[slot] as Array).size()
	return total

func _refresh_preview() -> void:
	if _preview_character != null and is_instance_valid(_preview_character):
		_preview_character.free()
	_preview_character = CharacterAssembler.assemble(_character, _preview_root, Vector2.ZERO)

# --------------------------------------------------------------------------
# Saved character list + status line
# --------------------------------------------------------------------------

func _refresh_load_list() -> void:
	if _load_option == null:
		return
	# Keep whatever the user had picked. This gets called from the
	# filesystem-changed hook, which fires often — so blindly resetting to
	# the placeholder would silently wipe their selection before they ever
	# press Load.
	var previous: Variant = null
	if _load_option.selected > 0 and _load_option.selected < _load_option.item_count:
		previous = _load_option.get_item_metadata(_load_option.selected)
	_load_option.clear()
	_load_option.add_item("— load character —")
	_load_option.set_item_disabled(0, true)
	var restored := 0
	for path in CharacterDatabase.list_characters():
		_load_option.add_item(path.get_file().get_basename())
		_load_option.set_item_metadata(_load_option.item_count - 1, path)
		if previous != null and String(previous) == String(path):
			restored = _load_option.item_count - 1
	_load_option.select(restored)

func _scan_filesystem() -> void:
	if not Engine.is_editor_hint():
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem != null:
		filesystem.scan()

func _set_status(message: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.modulate = Color(1.0, 0.55, 0.55) if is_error else Color(1.0, 1.0, 1.0)

static func _to_file_name(value: String) -> String:
	var file_name := value.strip_edges().replace(" ", "_")
	for bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		file_name = file_name.replace(bad, "")
	return file_name if not file_name.is_empty() else "character"
