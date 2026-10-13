class_name CarChatter
extends CanvasLayer
## Talk in the car while the player drives: a small cardboard board low on the
## screen with the speaker's name over their line, typed out in their own
## voice (SpeechPlayer), one line after another. Used while Grandpa rides
## along in "Visiting Hours" (ExStory). Hidden during cutscenes and menus;
## the queue waits for them.

signal finished

const LAYER := 40
const BOARD_SIZE := Vector2(620.0, 92.0)
## How long a line stays up once typed: a beat plus a little per letter.
const HOLD := 0.9
const HOLD_PER_LETTER := 0.035

var _board: ScrapPanel
var _name: Label
var _line: Label
var _speech: SpeechPlayer
## Lines waiting: [speaker name, CharacterData, text, sound or &""].
var _queue: Array = []
var _hold := 0.0
var _talking := false

func _ready() -> void:
	layer = LAYER
	_board = ScrapPanel.new()
	_board.body_color = UiPalette.CARDBOARD_BASE
	_board.shade_color = UiPalette.CARDBOARD_SHADE
	_board.skirt_color = UiPalette.CARDBOARD_DARK
	_board.tilt_degrees = -0.8
	_board.jitter_seed = 241
	_board.nails = false
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_board.offset_left = -BOARD_SIZE.x * 0.5
	_board.offset_right = BOARD_SIZE.x * 0.5
	_board.offset_top = -BOARD_SIZE.y - 96.0
	_board.offset_bottom = -96.0
	add_child(_board)
	_name = _label(16, UiPalette.SURFACE_DARK, Vector2(18.0, 8.0))
	_line = _label(20, UiPalette.TEXT_BROWN, Vector2(18.0, 32.0))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size = Vector2(BOARD_SIZE.x - 36.0, 52.0)
	_speech = SpeechPlayer.new()
	add_child(_speech)
	_board.visible = false

func _label(font_size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = at
	label.size = Vector2(BOARD_SIZE.x - 36.0, 24.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(label)
	return label

## Queues a line; `sound` plays as it starts (a twitch, a laugh).
func say(speaker_name: String, character: CharacterData, text: String, sound: StringName = &"") -> void:
	_queue.append([speaker_name, character, text, sound])

## Drops whatever's still to be said (the moment's passed), and the line up now.
func clear() -> void:
	_queue.clear()
	_speech.finish()
	_talking = false
	_board.visible = false

func is_talking() -> bool:
	return _talking or not _queue.is_empty()

func _process(delta: float) -> void:
	var allowed := not Cutscenes.is_active() and Journal.hud_allowed() and not get_tree().paused
	_board.visible = allowed and _talking
	if not allowed:
		return
	if _talking:
		if _speech.is_typing():
			return
		_hold -= delta
		if _hold > 0.0:
			return
		_talking = false
		if _queue.is_empty():
			_board.visible = false
			finished.emit()
	if _queue.is_empty():
		return
	var next: Array = _queue.pop_front()
	_name.text = String(next[0]).to_upper()
	var text := PlayerProfile.fill(next[2])
	_speech.speak(_line, text, next[1])
	if next[3] != &"":
		Sfx.play(next[3], -6.0, 0.0)
	_hold = HOLD + text.length() * HOLD_PER_LETTER
	_talking = true
	_board.visible = true
