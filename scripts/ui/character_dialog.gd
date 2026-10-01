class_name CharacterDialog
extends CanvasLayer
## The standard "talking to someone" popup. The speaker stands torso-up on a
## board in the right third of the screen; their line sits on a cardboard
## board top-left with the options stacked as ScrapButtons under it.
##
## Everything slides and pops in when it opens (and back out when it closes),
## the line types itself out in the speaker's own gibberish voice (see
## CharacterVoice), and the speaker bobs while they talk. Number keys pick an option, Esc closes.
##
## Usage:
##   dialog.open("Scrap Dealer", preload("res://characters/punker.tres"))
##   dialog.say("Buyin' scrap.")
##   dialog.set_options([CharacterDialog.Option.new("Sell", _on_sell)])

signal closed

class Option:
	var text: String
	var action: Callable
	var disabled: bool

	func _init(option_text: String, option_action: Callable, option_disabled: bool = false) -> void:
		text = option_text
		action = option_action
		disabled = option_disabled

const OPTION_HEIGHT := 50.0
const OPTION_GAP := 10.0
const OPTION_FONT_SIZE := 22
## The slice of a character (in character space, feet at 0, +y down) that
## fills the portrait: the waist sits on the bottom edge, with headroom above
## for hair and hats.
const PORTRAIT_WAIST_Y := -92.0
const PORTRAIT_SPAN := 205.0
## How far the portrait board runs off the bottom of the screen, so the
## speaker is cut off at the waist by the screen edge, not by a board edge.
## Matches PortraitBoard's offset_bottom in the scene.
const PORTRAIT_BOARD_OVERHANG := 40.0
const OVERLAY_ALPHA := 0.45
const OPEN_TIME := 0.42
const CLOSE_TIME := 0.2
const OPTION_STAGGER := 0.06
const IDLE_BOB_PIXELS := 3.0
const TALK_SQUASH := 0.025

@onready var _overlay: ColorRect = $Overlay
@onready var _portrait_board: Control = $Frame/PortraitBoard
@onready var _portrait_clip: Control = $Frame/PortraitBoard/PortraitClip
@onready var _portrait_holder: Node2D = $Frame/PortraitBoard/PortraitClip/Holder
@onready var _name_label: Label = $Frame/PortraitBoard/NamePlate/NameLabel
@onready var _speech_board: Control = $Frame/SpeechBoard
@onready var _line_label: Label = $Frame/SpeechBoard/LineLabel
@onready var _note_label: Label = $Frame/SpeechBoard/NoteLabel
@onready var _options_box: Control = $Frame/Options

var _option_buttons: Array[ScrapButton] = []
var _options: Array = []
var _speaker: CharacterData = null
var _speech: SpeechPlayer
var _time: float = 0.0
var _portrait_rest := Vector2.ZERO
var _portrait_scale: float = 1.0
var _tween: Tween = null
var _closing: bool = false

const GROUP := &"character_dialog"

func _ready() -> void:
	add_to_group(GROUP)
	visible = false
	_speech_board.gui_input.connect(_on_speech_board_input)
	_speech = SpeechPlayer.new()
	add_child(_speech)

func is_open() -> bool:
	return visible and not _closing

## Pops the dialog up with `character` on the portrait board, talking in
## their own voice.
func open(speaker_name: String, character: CharacterData) -> void:
	_speaker = character
	_name_label.text = speaker_name.to_upper()
	_build_portrait(character)
	if _tween != null:
		_tween.kill()
	_closing = false
	visible = true
	_reset_positions()
	_layout_portrait()
	Sfx.play(&"dialog_open", -6.0, 0.05)

	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_overlay.color.a = 0.0
	_tween.tween_property(_overlay, "color:a", OVERLAY_ALPHA, OPEN_TIME * 0.6)
	var board_rest := _portrait_board.position
	_portrait_board.position.x += _portrait_board.size.x + 80.0
	_tween.tween_property(_portrait_board, "position", board_rest, OPEN_TIME)
	_portrait_holder.position.y = _portrait_rest.y + _portrait_clip.size.y
	_tween.tween_property(_portrait_holder, "position:y", _portrait_rest.y, OPEN_TIME).set_delay(OPEN_TIME * 0.35)
	_speech_board.scale = Vector2(0.6, 0.6)
	_tween.tween_property(_speech_board, "scale", Vector2.ONE, OPEN_TIME).set_delay(OPEN_TIME * 0.2)

## Replaces the current line and types it out.
## `{player}` in the line becomes the player's name (see PlayerProfile).
func say(line: String) -> void:
	_speech.speak(_line_label, PlayerProfile.fill(line), _speaker)

## Small print under the line (a wallet readout, a price list). Empty hides it.
func set_note(text: String) -> void:
	_note_label.text = text
	_note_label.visible = not text.is_empty()

## Shows `options` as numbered buttons. With the same number of options as
## already showing and `animate` off, the buttons are just relabelled in place,
## so refreshing a price doesn't make them all slide in again.
func set_options(options: Array, animate: bool = true) -> void:
	_options = options
	if not animate and options.size() == _option_buttons.size():
		for i in options.size():
			_apply_option(_option_buttons[i], i)
		return
	for button in _option_buttons:
		button.queue_free()
	_option_buttons.clear()
	for i in options.size():
		var button := ScrapButton.new()
		button.font_size = OPTION_FONT_SIZE
		button.tilt_degrees = [-1.2, 0.8, -0.5, 1.4][i % 4]
		button.jitter_seed = 40 + i
		button.pressed.connect(_choose.bind(i))
		_options_box.add_child(button)
		_option_buttons.append(button)
		_apply_option(button, i)
	_layout_options(animate)

func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_speech.finish()
	if _tween != null:
		_tween.kill()
	Sfx.play(&"dialog_open", -10.0, 0.05).pitch_scale *= 0.75
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(_overlay, "color:a", 0.0, CLOSE_TIME)
	_tween.tween_property(_portrait_board, "position:x",
			_portrait_board.position.x + _portrait_board.size.x + 80.0, CLOSE_TIME)
	_tween.tween_property(_speech_board, "scale", Vector2(0.6, 0.6), CLOSE_TIME)
	for button in _option_buttons:
		_tween.tween_property(button, "position:x", -_options_box.size.x - 80.0, CLOSE_TIME)
	_tween.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	visible = false
	_closing = false
	_reset_positions()
	closed.emit()

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_animate_speaker()

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	var index: int = event.keycode - KEY_1
	if index < 0 or index >= _options.size() or index > 8:
		return
	# Handled before choosing: an option can change scenes, which frees this
	# node before the call even returns.
	get_viewport().set_input_as_handled()
	_choose(index)

func _choose(index: int) -> void:
	var option: Option = _options[index]
	if option.disabled or _closing:
		return
	option.action.call()

func _apply_option(button: ScrapButton, index: int) -> void:
	var option: Option = _options[index]
	button.text = "%d. %s" % [index + 1, option.text]
	button.disabled = option.disabled

func _layout_options(animate: bool) -> void:
	for i in _option_buttons.size():
		var button := _option_buttons[i]
		button.size = Vector2(_options_box.size.x, OPTION_HEIGHT)
		var rest := Vector2(0.0, i * (OPTION_HEIGHT + OPTION_GAP))
		if not animate:
			button.position = rest
			continue
		button.position = Vector2(-_options_box.size.x - 80.0, rest.y)
		var tween := button.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(OPEN_TIME * 0.4 + i * OPTION_STAGGER)
		tween.tween_property(button, "position:x", 0.0, OPEN_TIME)

func _build_portrait(character: CharacterData) -> void:
	for child in _portrait_holder.get_children():
		child.queue_free()
	if character == null:
		return
	var rig := CharacterRig.new()
	rig.character_data = character
	_portrait_holder.add_child(rig)

## Scale the character so the waist-up slice fills the clip, feet hanging
## below the bottom edge where the clip hides them.
func _layout_portrait() -> void:
	_portrait_scale = _portrait_clip.size.y / PORTRAIT_SPAN
	_portrait_holder.scale = Vector2.ONE * _portrait_scale
	_portrait_rest = Vector2(_portrait_clip.size.x * 0.5,
			_portrait_clip.size.y - PORTRAIT_WAIST_Y * _portrait_scale)
	_portrait_holder.position = _portrait_rest

## Undo anything a half-finished tween left behind, back to the anchored layout.
func _reset_positions() -> void:
	_portrait_board.offset_left = 0.0
	_portrait_board.offset_right = 0.0
	_portrait_board.offset_top = 0.0
	_portrait_board.offset_bottom = PORTRAIT_BOARD_OVERHANG
	_speech_board.scale = Vector2.ONE
	_speech_board.pivot_offset = Vector2(0.0, _speech_board.size.y)
	_layout_options(false)

## A slow idle bob, plus a quick squash while the line is still typing so the
## speaker looks like they're the one talking.
func _animate_speaker() -> void:
	if _tween != null and _tween.is_running():
		return
	_portrait_holder.position.y = _portrait_rest.y + sin(_time * TAU * 0.7) * IDLE_BOB_PIXELS
	var squash := sin(_time * TAU * 6.0) * TALK_SQUASH if _speech.is_typing() else 0.0
	_portrait_holder.scale = Vector2(_portrait_scale * (1.0 - squash), _portrait_scale * (1.0 + squash))

## Clicking the line while it's still typing shows the rest of it at once.
func _on_speech_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_speech.finish()
