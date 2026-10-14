class_name RandomRacePopup
extends CanvasLayer
## Ctrl+G opens the random race popup: pick a race type, a tier, whose cars
## race and what you drive (a random car, your garage car, or one picked from a
## tier's rival pool in RandomRaceCarPicker), then roll. Ctrl+N replays the last
## rolled race exactly (same seed, venue, cars and weather) from the map or
## mid-race, so one race can be rerun until it's right. The race is a DebugRace:
## nothing is recorded or paid. The settings, the picked car and the last race
## are kept in settings.cfg.
##
## Every race started here has a RaceCode. Ctrl+C during the race copies it
## (and shows it), and pasting one into the popup's code field plays that race.
##
## Not F-keys: a game embedded in the Godot editor hands F5-F8 to the editor's
## run bar, and F8 there stops the game.
##
## Registered as the `RandomRace` autoload. Not offered on menu screens, where
## there's no save loaded to come back to.

enum Venue { DRAG, HILL, RALLY, DERBY, RAMP }
enum Driver { RANDOM, GARAGE, PICKED }

const VENUE_NAMES := {
	Venue.DRAG: "Drag Strip",
	Venue.HILL: "Hill Climb",
	Venue.RALLY: "Rally",
	Venue.DERBY: "Derby",
	Venue.RAMP: "Ramp",
}
const VENUE_SCENES := {
	Venue.DRAG: "res://scenes/race/race_drag_strip.tscn",
	Venue.HILL: "res://scenes/race/race_hill_climb.tscn",
	Venue.RALLY: "res://scenes/race/race_rally.tscn",
	Venue.DERBY: "res://scenes/race/race_derby.tscn",
	Venue.RAMP: "res://scenes/race/race_ramp.tscn",
}
## The roster a venue rates its rivals on; the rest race the drag roster.
const VENUE_COURSES := {
	Venue.HILL: RaceProgression.Course.HILL,
	Venue.DERBY: RaceProgression.Course.DERBY,
}
const TIERS := [1, 2, 3, 4]
## Stands for "pick one at random each roll" in the venue and tier settings.
const ANY := -1
const MENU_SCENES_DIR := "res://scenes/menu/"
const OPEN_KEY := KEY_G
const REPLAY_KEY := KEY_N
const COPY_CODE_KEY := KEY_C
const TOAST_SECONDS := 3.5
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "random_race"

var _venue_setting := ANY
var _tier_setting := ANY
var _random_parts := false
var _driver_setting := Driver.RANDOM
## The roster spec picked in RandomRaceCarPicker, empty until one is.
var _picked_spec: Dictionary = {}
var _picked_tier := 1
## What Ctrl+N replays: {"venue", "tier", "seed", "driver", "picked_spec",
## "weather"}, empty until a race is rolled.
var _last_race: Dictionary = {}
## The RaceCode of the last race started here.
var _last_code := ""
## The race scene the last start loaded, so Ctrl+C only answers inside it.
var _race_scene_id := 0

var _backdrop: ColorRect
var _venue_buttons: Array[ScrapButton] = []
var _tier_buttons: Array[ScrapButton] = []
var _cars_buttons: Array[ScrapButton] = []
var _driver_buttons: Array[ScrapButton] = []
var _picked_car_label: Label
var _car_picker: RandomRaceCarPicker
var _code_edit: LineEdit
var _code_status_label: Label
var _toast: ScrapPanel
var _toast_code_label: Label
var _toast_tween: Tween

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_backdrop.visible = false
	_load_settings()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_ESCAPE and _is_open():
		get_viewport().set_input_as_handled()
		if _car_picker.visible:
			_car_picker.close()
		else:
			_close()
		return
	if not event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed:
		return
	match event.physical_keycode:
		OPEN_KEY:
			get_viewport().set_input_as_handled()
			if _is_open():
				_close()
			elif _can_start():
				_open()
		REPLAY_KEY:
			get_viewport().set_input_as_handled()
			replay_last_race()
		COPY_CODE_KEY:
			if _is_open() or _in_started_race():
				get_viewport().set_input_as_handled()
				_copy_code()

## Picks a new race from the current settings and loads straight into it.
func roll_and_start() -> void:
	if not _can_start():
		Sfx.play(&"denied", -6.0)
		return
	var tier := 0
	if not _random_parts:
		tier = _tier_setting if _tier_setting != ANY else TIERS.pick_random()
	_last_race = {
		"venue": _venue_setting if _venue_setting != ANY else VENUE_SCENES.keys().pick_random(),
		"tier": tier,
		"seed": randi(),
		"driver": _driver_setting,
		"picked_spec": _picked_spec,
		"weather": Weather.snapshot(),
	}
	_save_settings()
	Sfx.play(&"dice_roll", -4.0)
	_start(_last_race)

## Runs the last rolled race again, or rolls one if there isn't one yet.
func replay_last_race() -> void:
	if _last_race.is_empty():
		roll_and_start()
		return
	if not _can_start():
		Sfx.play(&"denied", -6.0)
		return
	Sfx.play(&"ignition_click", -4.0)
	_start(_last_race)

## Runs the race a RaceCode describes; an unreadable code says so instead.
func play_code(code: String) -> void:
	var race := RaceCode.decode(code)
	if race.is_empty():
		Sfx.play(&"denied", -6.0)
		_code_status_label.text = "That code doesn't read right, or names a part that's gone."
		return
	if not _can_start():
		Sfx.play(&"denied", -6.0)
		return
	_last_race = race
	_save_settings()
	Sfx.play(&"ignition_click", -4.0)
	_start(race)

func _start(race: Dictionary) -> void:
	_close()
	var player_car := _player_car(race["driver"], race["picked_spec"])
	_last_code = RaceCode.encode(race, player_car)
	_save_settings()
	await SceneLoader.change_scene(VENUE_SCENES[race["venue"]], func() -> void:
		Weather.restore(race["weather"])
		DebugRace.request(race["tier"], player_car, race["seed"]))
	_race_scene_id = get_tree().current_scene.get_instance_id()

func _in_started_race() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.get_instance_id() == _race_scene_id

func _copy_code() -> void:
	if _last_code.is_empty():
		Sfx.play(&"denied", -6.0)
		return
	DisplayServer.clipboard_set(_last_code)
	Sfx.play(&"wink_ting", -8.0)
	_show_toast(_last_code)

## The car for the first lane, or null to fill it like the rest.
func _player_car(driver: Driver, picked_spec: Dictionary) -> CarModelData:
	match driver:
		Driver.GARAGE:
			return Inventory.get_selected_car()
		Driver.PICKED:
			return RaceProgression.rival_car_model(picked_spec)
	return null

func _can_start() -> bool:
	if SceneLoader.is_loading() or Cutscenes.is_active():
		return false
	var scene := get_tree().current_scene
	return scene != null and not scene.scene_file_path.begins_with(MENU_SCENES_DIR)

func _is_open() -> bool:
	return _backdrop.visible

func _open() -> void:
	_backdrop.visible = true
	_code_edit.text = _last_code
	_code_status_label.text = ""
	Sfx.play(&"dialog_open", -6.0)

func _close() -> void:
	if _is_open():
		_code_edit.release_focus()
		_car_picker.visible = false
		_backdrop.visible = false
		Sfx.play(&"dialog_open", -10.0).pitch_scale *= 0.75

## Drops a plate with the copied code in from the top of the screen.
func _show_toast(code: String) -> void:
	_toast_code_label.text = code
	var shown_y := 18.0
	var hidden_y := -_toast.size.y - 20.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.position.y = hidden_y
	_toast.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "position:y", shown_y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "position:y", hidden_y, 0.2).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(_toast.hide)

# --- Building ------------------------------------------------------------------

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.5)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	var panel := ScrapPanel.new()
	panel.body_color = UiPalette.STEEL_DARK
	panel.shade_color = Color(0.33, 0.36, 0.41)
	panel.skirt_color = UiPalette.METAL_GREY
	panel.tilt_degrees = 0.5
	panel.jitter_seed = 81
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -470.0
	panel.offset_right = 470.0
	panel.offset_top = -290.0
	panel.offset_bottom = 290.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.add_child(panel)

	var title_plate := ScrapPanel.new()
	title_plate.body_color = UiPalette.ACCENT_YELLOW
	title_plate.shade_color = Color(0.85, 0.66, 0.08)
	title_plate.skirt_color = Color(0.76, 0.58, 0.07)
	title_plate.nails = false
	title_plate.tilt_degrees = -3.0
	title_plate.jitter_seed = 82
	title_plate.position = Vector2(22.0, -14.0)
	title_plate.size = Vector2(240.0, 58.0)
	title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_plate)
	var title := _make_label("RANDOM RACE", 26, UiPalette.INK)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.offset_bottom = -6.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_plate.add_child(title)

	var hint := _make_label("Ctrl+N replays the last race. Ctrl+C in a race copies its code.", 15, UiPalette.STEEL_LIGHT)
	hint.position = Vector2(280.0, 20.0)
	hint.size = Vector2(636.0, 24.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(hint)

	var rows := VBoxContainer.new()
	rows.position = Vector2(30.0, 72.0)
	rows.size = Vector2(880.0, 300.0)
	rows.add_theme_constant_override("separation", 18)
	panel.add_child(rows)

	_venue_buttons = _add_choice_row(rows, "Race", _venue_options().map(_venue_label), func(index: int) -> void:
		_venue_setting = _venue_options()[index])
	_tier_buttons = _add_choice_row(rows, "Tier", _tier_options().map(_tier_label), func(index: int) -> void:
		_tier_setting = _tier_options()[index])
	_cars_buttons = _add_choice_row(rows, "Cars", ["Tier Rivals", "Random Junk"], func(index: int) -> void:
		_random_parts = index == 1)
	_driver_buttons = _add_choice_row(rows, "You Drive", ["A Random Car", "Your Garage Car", "Pick a Car"], func(index: int) -> void:
		if index == Driver.PICKED:
			_open_car_picker()
		else:
			_driver_setting = index)

	_picked_car_label = _make_label("", 16, UiPalette.STEEL_LIGHT)
	_picked_car_label.position = Vector2(172.0, 330.0)
	_picked_car_label.size = Vector2(740.0, 24.0)
	panel.add_child(_picked_car_label)

	var roll_button := ScrapButton.new()
	roll_button.text = "Roll It!"
	roll_button.font_size = 26
	roll_button.tilt_degrees = -1.5
	roll_button.jitter_seed = 99
	roll_button.focus_mode = Control.FOCUS_NONE
	roll_button.position = Vector2(700.0, 490.0)
	roll_button.size = Vector2(210.0, 60.0)
	roll_button.pressed.connect(roll_and_start)
	panel.add_child(roll_button)

	_build_code_row(panel)
	_build_toast()

	_car_picker = RandomRaceCarPicker.new()
	_car_picker.car_picked.connect(_on_car_picked)
	add_child(_car_picker)

func _build_code_row(panel: ScrapPanel) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(30.0, 380.0)
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var label := _make_label("Race Code", 20, UiPalette.TEXT_LIGHT)
	label.custom_minimum_size = Vector2(130.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_code_edit = LineEdit.new()
	_code_edit.custom_minimum_size = Vector2(430.0, 46.0)
	_code_edit.placeholder_text = "Paste a race code"
	_code_edit.add_theme_font_size_override("font_size", 16)
	_code_edit.text_submitted.connect(play_code)
	_code_edit.text_changed.connect(func(_text: String) -> void: _code_status_label.text = "")
	row.add_child(_code_edit)
	var play_button := _make_row_button("Play Code", 1.5, 120)
	play_button.pressed.connect(func() -> void: play_code(_code_edit.text))
	row.add_child(play_button)
	var copy_button := _make_row_button("Copy", -1.5, 121)
	copy_button.pressed.connect(func() -> void:
		if not _code_edit.text.strip_edges().is_empty():
			DisplayServer.clipboard_set(_code_edit.text.strip_edges())
			Sfx.play(&"wink_ting", -8.0))
	row.add_child(copy_button)

	_code_status_label = _make_label("", 15, UiPalette.ACCENT_YELLOW)
	_code_status_label.position = Vector2(172.0, 436.0)
	_code_status_label.size = Vector2(740.0, 24.0)
	panel.add_child(_code_status_label)

func _make_row_button(text: String, tilt: float, jitter_seed: int) -> ScrapButton:
	var button := ScrapButton.new()
	button.text = text
	button.font_size = 18
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(14.0 * text.length() + 30.0, 46.0)
	button.tilt_degrees = tilt
	button.jitter_seed = jitter_seed
	return button

func _build_toast() -> void:
	_toast = ScrapPanel.new()
	_toast.body_color = UiPalette.ACCENT_YELLOW
	_toast.shade_color = Color(0.85, 0.66, 0.08)
	_toast.skirt_color = Color(0.76, 0.58, 0.07)
	_toast.nails = false
	_toast.tilt_degrees = -1.5
	_toast.jitter_seed = 86
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -330.0
	_toast.offset_right = 330.0
	_toast.size.y = 78.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	var title := _make_label("RACE CODE COPIED", 20, UiPalette.INK)
	title.position = Vector2(0.0, 8.0)
	title.size = Vector2(660.0, 26.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(title)
	_toast_code_label = _make_label("", 15, UiPalette.TEXT_BROWN)
	_toast_code_label.position = Vector2(16.0, 38.0)
	_toast_code_label.size = Vector2(628.0, 24.0)
	_toast_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_code_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast.add_child(_toast_code_label)

## A label and one ScrapButton per option; pressing one calls `on_pick` with
## its index.
func _add_choice_row(rows: VBoxContainer, label_text: String, options: Array, on_pick: Callable) -> Array[ScrapButton]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	rows.add_child(row)
	var label := _make_label(label_text, 20, UiPalette.TEXT_LIGHT)
	label.custom_minimum_size = Vector2(130.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var buttons: Array[ScrapButton] = []
	for i in options.size():
		var button := ScrapButton.new()
		button.text = options[i]
		button.font_size = 18
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(maxf(90.0, 14.0 * String(options[i]).length() + 30.0), 46.0)
		button.tilt_degrees = 1.5 if (i + rows.get_child_count()) % 2 == 0 else -1.5
		button.jitter_seed = rows.get_child_count() * 10 + i
		button.pressed.connect(func() -> void:
			on_pick.call(i)
			_refresh()
			_save_settings())
		row.add_child(button)
		buttons.append(button)
	return buttons

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _venue_options() -> Array:
	return [ANY] + VENUE_SCENES.keys()

func _tier_options() -> Array:
	return [ANY] + TIERS

func _venue_label(venue: int) -> String:
	return "Any" if venue == ANY else VENUE_NAMES[venue]

func _tier_label(tier: int) -> String:
	return "Any" if tier == ANY else "Tier %d" % tier

func _open_car_picker() -> void:
	var venue_course: RaceProgression.Course = VENUE_COURSES.get(_venue_setting, RaceProgression.Course.DRAG)
	var pool_tier := _picked_tier if not _picked_spec.is_empty() else _tier_setting
	_car_picker.open(pool_tier, venue_course, _picked_spec)

func _on_car_picked(spec: Dictionary) -> void:
	_picked_spec = spec
	_picked_tier = _car_picker.tier
	_driver_setting = Driver.PICKED
	_refresh()
	_save_settings()

func _refresh() -> void:
	_select(_venue_buttons, _venue_options().find(_venue_setting))
	_select(_tier_buttons, _tier_options().find(_tier_setting))
	_select(_cars_buttons, 1 if _random_parts else 0)
	_select(_driver_buttons, _driver_setting)
	_picked_car_label.visible = _driver_setting == Driver.PICKED
	if not _picked_spec.is_empty():
		_picked_car_label.text = "Driving: %s (Tier %d pool)" % [_car_picker.car_label(_picked_spec), _picked_tier]
	# Random junk isn't drawn from a tier, so the tier doesn't apply.
	for button in _tier_buttons:
		button.disabled = _random_parts

func _select(buttons: Array[ScrapButton], index: int) -> void:
	for i in buttons.size():
		buttons[i].selected = i == index

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

# --- Settings ------------------------------------------------------------------

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_venue_setting = config.get_value(SETTINGS_SECTION, "venue", _venue_setting)
	_tier_setting = config.get_value(SETTINGS_SECTION, "tier", _tier_setting)
	_random_parts = config.get_value(SETTINGS_SECTION, "random_parts", _random_parts)
	_picked_spec = config.get_value(SETTINGS_SECTION, "picked_spec", _picked_spec)
	_driver_setting = config.get_value(SETTINGS_SECTION, "driver", _driver_setting)
	_picked_tier = config.get_value(SETTINGS_SECTION, "picked_tier", _picked_tier)
	_last_race = config.get_value(SETTINGS_SECTION, "last_race", _last_race)
	_last_code = config.get_value(SETTINGS_SECTION, "last_code", _last_code)
	# A roster rebuild can drop the picked car's parts; fall back rather than
	# racing a car that can't be built.
	if not _spec_parts_exist(_picked_spec):
		_picked_spec = {}
	if _driver_setting == Driver.PICKED and _picked_spec.is_empty():
		_driver_setting = Driver.RANDOM
	if not _last_race.is_empty() and not _spec_parts_exist(_last_race["picked_spec"]):
		_last_race = {}

func _save_settings() -> void:
	if SaveSystem.is_saving_disabled():
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, "venue", _venue_setting)
	config.set_value(SETTINGS_SECTION, "tier", _tier_setting)
	config.set_value(SETTINGS_SECTION, "random_parts", _random_parts)
	config.set_value(SETTINGS_SECTION, "driver", _driver_setting)
	config.set_value(SETTINGS_SECTION, "picked_spec", _picked_spec)
	config.set_value(SETTINGS_SECTION, "picked_tier", _picked_tier)
	config.set_value(SETTINGS_SECTION, "last_race", _last_race)
	config.set_value(SETTINGS_SECTION, "last_code", _last_code)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("RandomRacePopup: save failed (error %d)" % err)

static func _spec_parts_exist(spec: Dictionary) -> bool:
	if spec.is_empty():
		return true
	var scene_paths: Array = [spec["body"], spec["engine"]] + Array(spec["wheels"]) + Array(spec.get("accessories", []))
	return scene_paths.all(func(path: String) -> bool: return ResourceLoader.exists(path))
