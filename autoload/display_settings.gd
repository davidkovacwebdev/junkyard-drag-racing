extends Node
## Fullscreen toggle (autoload singleton "DisplaySettings"). F11 flips it from
## anywhere, the settings screen has a button for it, and the choice is kept
## in user://settings.cfg next to the audio levels. Starts windowed.

signal fullscreen_changed(fullscreen: bool)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "display"
const TOGGLE_KEY := KEY_F11

var fullscreen := false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		fullscreen = config.get_value(SECTION, "fullscreen", false)
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == TOGGLE_KEY:
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()

func set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	fullscreen = value
	_apply()
	_save()
	Sfx.play(&"ui_click", Sfx.UI_CLICK_VOLUME_DB)
	fullscreen_changed.emit(fullscreen)

func _apply() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "fullscreen", fullscreen)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("DisplaySettings: save failed (error %d)" % err)
