class_name RandomRacePopup
extends CanvasLayer
## Ctrl+G opens the random race popup: pick a race type, a tier and whose cars
## race, then roll. Ctrl+N rolls a fresh race with the same settings and starts it
## straight away, from the map or mid-race, so a run of random races can be
## recorded back to back. The race is a DebugRace: nothing is recorded or paid.
##
## Not F-keys: a game embedded in the Godot editor hands F5-F8 to the editor's
## run bar, and F8 there stops the game.
##
## Registered as the `RandomRace` autoload. Not offered on menu screens, where
## there's no save loaded to come back to.

enum Venue { DRAG, HILL, RALLY, DERBY, RAMP }

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
const TIERS := [1, 2, 3, 4]
## Stands for "pick one at random each roll" in the venue and tier settings.
const ANY := -1
const MENU_SCENES_DIR := "res://scenes/menu/"
const OPEN_KEY := KEY_G
const ROLL_KEY := KEY_N

var _venue_setting := ANY
var _tier_setting := ANY
var _random_parts := false
var _drive_garage_car := false

var _backdrop: ColorRect
var _venue_buttons: Array[ScrapButton] = []
var _tier_buttons: Array[ScrapButton] = []
var _cars_buttons: Array[ScrapButton] = []
var _driver_buttons: Array[ScrapButton] = []

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_ESCAPE and visible:
		get_viewport().set_input_as_handled()
		_close()
		return
	if not event.is_command_or_control_pressed() or event.shift_pressed or event.alt_pressed:
		return
	match event.physical_keycode:
		OPEN_KEY:
			get_viewport().set_input_as_handled()
			if visible:
				_close()
			elif _can_start():
				_open()
		ROLL_KEY:
			get_viewport().set_input_as_handled()
			roll_and_start()

## Picks a race from the current settings and loads straight into it.
func roll_and_start() -> void:
	if not _can_start():
		Sfx.play(&"denied", -6.0)
		return
	var venue: int = _venue_setting if _venue_setting != ANY else VENUE_SCENES.keys().pick_random()
	var tier := 0
	if not _random_parts:
		tier = _tier_setting if _tier_setting != ANY else TIERS.pick_random()
	_close()
	Sfx.play(&"dice_roll", -4.0)
	var garage_car := _drive_garage_car
	SceneLoader.change_scene(VENUE_SCENES[venue], func() -> void:
		DebugRace.request(tier, garage_car))

func _can_start() -> bool:
	if SceneLoader.is_loading() or Cutscenes.is_active():
		return false
	var scene := get_tree().current_scene
	return scene != null and not scene.scene_file_path.begins_with(MENU_SCENES_DIR)

func _open() -> void:
	visible = true
	Sfx.play(&"dialog_open", -6.0)

func _close() -> void:
	if visible:
		visible = false
		Sfx.play(&"dialog_open", -10.0).pitch_scale *= 0.75

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
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
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

	var hint := _make_label("Ctrl+G closes. Ctrl+N rolls a new race any time.", 15, UiPalette.STEEL_LIGHT)
	hint.position = Vector2(300.0, 20.0)
	hint.size = Vector2(616.0, 24.0)
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
	_driver_buttons = _add_choice_row(rows, "You Drive", ["A Random Car", "Your Garage Car"], func(index: int) -> void:
		_drive_garage_car = index == 1)

	var roll_button := ScrapButton.new()
	roll_button.text = "Roll It!"
	roll_button.font_size = 26
	roll_button.tilt_degrees = -1.5
	roll_button.jitter_seed = 99
	roll_button.focus_mode = Control.FOCUS_NONE
	roll_button.position = Vector2(700.0, 410.0)
	roll_button.size = Vector2(210.0, 60.0)
	roll_button.pressed.connect(roll_and_start)
	panel.add_child(roll_button)

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
			_refresh())
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

func _refresh() -> void:
	_select(_venue_buttons, _venue_options().find(_venue_setting))
	_select(_tier_buttons, _tier_options().find(_tier_setting))
	_select(_cars_buttons, 1 if _random_parts else 0)
	_select(_driver_buttons, 1 if _drive_garage_car else 0)
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
