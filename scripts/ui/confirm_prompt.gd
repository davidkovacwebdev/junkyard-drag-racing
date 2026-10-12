class_name ConfirmPrompt
extends CanvasLayer
## A yes/no board over a dimmed, paused screen. `await ConfirmPrompt.ask(...)`
## returns true on confirm (button, Enter or Y) and false on cancel (button,
## Esc or N). It swallows every other input while up and frees itself after.

signal answered(confirmed: bool)

const LAYER := 90
const BOARD_SIZE := Vector2(480.0, 230.0)
const OVERLAY_ALPHA := 0.5
const FADE_TIME := 0.12

var _overlay: ColorRect
var _board: ScrapPanel
var _was_paused := false
var _closing := false

static func ask(tree: SceneTree, title: String, message: String, confirm_text: String) -> bool:
	var prompt := ConfirmPrompt.new()
	tree.root.add_child(prompt)
	prompt._build(title, message, confirm_text)
	return await prompt.answered

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	Sfx.play(&"dialog_open", -6.0, 0.05)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if _closing or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_Y:
			_close(true)
		KEY_ESCAPE, KEY_N:
			_close(false)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var focused := get_viewport().gui_get_focus_owner() as ScrapButton
			if focused != null:
				focused.pressed.emit()

func _close(confirmed: bool) -> void:
	if _closing:
		return
	_closing = true
	Sfx.play(&"ui_click", Sfx.UI_CLICK_VOLUME_DB + 2.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_overlay, "color:a", 0.0, FADE_TIME)
	tween.tween_property(_board, "scale", Vector2(1.06, 0.0), FADE_TIME)
	await tween.finished
	get_tree().paused = _was_paused
	answered.emit(confirmed)
	queue_free()

func _build(title: String, message: String, confirm_text: String) -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var centre := Control.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(centre)

	_board = ScrapPanel.new()
	_board.tilt_degrees = 1.5
	_board.jitter_seed = 427
	_board.size = BOARD_SIZE
	_board.position = -BOARD_SIZE * 0.5
	_board.pivot_offset = BOARD_SIZE * 0.5
	_board.scale = Vector2(0.9, 1.08)
	centre.add_child(_board)

	var title_label := _make_label(title.to_upper(), 28, UiPalette.ACCENT_YELLOW)
	title_label.position = Vector2(0.0, 22.0)
	title_label.size = Vector2(BOARD_SIZE.x, 34.0)
	_board.add_child(title_label)

	var message_label := _make_label(message, 18, UiPalette.TEXT_LIGHT)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.position = Vector2(32.0, 64.0)
	message_label.size = Vector2(BOARD_SIZE.x - 64.0, 64.0)
	_board.add_child(message_label)

	var confirm_button := _make_button(confirm_text, Vector2(40.0, 148.0), -1.5, 431)
	confirm_button.pressed.connect(_close.bind(true))
	var cancel_button := _make_button("Cancel", Vector2(BOARD_SIZE.x - 40.0 - 180.0, 148.0), 1.0, 433)
	cancel_button.pressed.connect(_close.bind(false))
	cancel_button.grab_focus.call_deferred()

	var tween := create_tween().set_parallel()
	tween.tween_property(_overlay, "color:a", OVERLAY_ALPHA, FADE_TIME)
	tween.tween_property(_board, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _make_button(text: String, at: Vector2, tilt: float, seed: int) -> ScrapButton:
	var button := ScrapButton.new()
	button.text = text
	button.font_size = 22
	button.tilt_degrees = tilt
	button.jitter_seed = seed
	button.position = at
	button.size = Vector2(180.0, 50.0)
	_board.add_child(button)
	return button

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
