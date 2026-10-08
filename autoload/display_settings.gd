extends Node
## Fullscreen and VSync toggles (autoload singleton "DisplaySettings"). F11
## flips fullscreen from anywhere, the settings screen has buttons for both,
## and the choices are kept in user://settings.cfg next to the audio levels.
## Starts windowed with VSync on.

signal fullscreen_changed(fullscreen: bool)
signal vsync_changed(vsync: bool)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "display"
const TOGGLE_KEY := KEY_F11

var fullscreen := false
var vsync := true

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		fullscreen = config.get_value(SECTION, "fullscreen", false)
		vsync = config.get_value(SECTION, "vsync", true)
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

func set_vsync(value: bool) -> void:
	if value == vsync:
		return
	vsync = value
	_apply()
	_save()
	Sfx.play(&"ui_click", Sfx.UI_CLICK_VOLUME_DB)
	vsync_changed.emit(vsync)

func _apply() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "vsync", vsync)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("DisplaySettings: save failed (error %d)" % err)
