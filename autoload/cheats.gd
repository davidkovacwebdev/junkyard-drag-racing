extends CanvasLayer
## The cheat switch (autoload `Cheats`): every debug and cheat shortcut (the F1
## dev menu, Ctrl+M money, P every part, F2-F6, the F5 quest board, K / Ctrl+K
## time, J weather, Ctrl+G random races, T debug races, Ctrl+Shift save-slot
## switching) does nothing unless `enabled`.
##
## Off by default, exports included. Typing CODE anywhere in the game (no text
## box needed, the letters just have to come in a row) flips it on, or back off,
## with a little board saying so. The choice is kept in user://settings.cfg, so
## it stays on for that computer. Launching with `-- --cheats` also turns it on,
## for that run only.

signal changed(enabled: bool)

const CODE := "eugenrules"
const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "cheats"
const LAUNCH_FLAG := "--cheats"
const NOTICE_TIME := 1.8

var enabled := false

var _typed := ""
var _notice: ScrapPanel
var _notice_label: Label
var _notice_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		enabled = config.get_value(SECTION, "enabled", false)
	if LAUNCH_FLAG in OS.get_cmdline_user_args():
		enabled = true
	_build_notice()

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.unicode == 0:
		return
	_typed = (_typed + char(key.unicode).to_lower()).right(CODE.length())
	if _typed == CODE:
		_typed = ""
		set_enabled(not enabled)

func set_enabled(value: bool) -> void:
	enabled = value
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, "enabled", enabled)
	config.save(SETTINGS_PATH)
	if enabled:
		Sfx.play(&"wink_ting", -4.0, 0.0)
	else:
		Sfx.play(&"phone_beep", -6.0, 0.0).pitch_scale = 0.7
	_show_notice("CHEATS ON" if enabled else "CHEATS OFF")
	changed.emit(enabled)

func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice.visible = true
	_notice.scale = Vector2(0.3, 0.3)
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_notice_tween.tween_interval(NOTICE_TIME)
	_notice_tween.tween_callback(func() -> void: _notice.visible = false)

func _build_notice() -> void:
	_notice = ScrapPanel.new()
	_notice.nails = false
	_notice.tilt_degrees = -2.0
	_notice.jitter_seed = 113
	_notice.size = Vector2(240, 60)
	_notice.pivot_offset = _notice.size / 2.0
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.position = Vector2(-120, 40)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	add_child(_notice)
	_notice_label = Label.new()
	_notice_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.add_theme_font_size_override("font_size", 26)
	_notice_label.add_theme_color_override("font_color", UiPalette.TEXT_LIGHT)
	_notice.add_child(_notice_label)
