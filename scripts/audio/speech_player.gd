class_name SpeechPlayer
extends AudioStreamPlayer
## Types a line into a Label letter by letter while the speaker "says" it in
## their CharacterVoice gibberish. Shared by CharacterDialog and cutscene
## subtitles so a character sounds the same everywhere.

signal typing_finished

@export var characters_per_second: float = 50.0
## A syllable every this many typed letters.
@export var syllable_every: int = 3

var _label: Label = null
var _voice_streams: Dictionary = {}
## The last vowel typed since the previous syllable, so the syllable sounds
## like the word it's spelling out.
var _pending_vowel: String = ""
var _letters_since_syllable: int = 0
var _typed: float = 0.0
var _typing: bool = false

func _ready() -> void:
	bus = AudioSettings.UI
	volume_db = -8.0

func speak(target: Label, line: String, character: CharacterData) -> void:
	_label = target
	_voice_streams = CharacterVoice.streams_for(character)
	_label.text = line
	_label.visible_characters = 0
	_typed = 0.0
	_letters_since_syllable = 0
	_pending_vowel = ""
	_typing = not line.is_empty()

func is_typing() -> bool:
	return _typing

## Shows the rest of the line at once.
func finish() -> void:
	if not _typing:
		return
	_typing = false
	if is_instance_valid(_label):
		_label.visible_characters = -1
	typing_finished.emit()

func _process(delta: float) -> void:
	if not _typing:
		return
	if not is_instance_valid(_label):
		_typing = false
		return
	var total := _label.get_total_character_count()
	var before := _label.visible_characters
	_typed += characters_per_second * delta
	var now := mini(int(_typed), total)
	for i in range(before, now):
		var letter := _label.text[i]
		if not letter.is_valid_identifier() and not letter.is_valid_int():
			continue
		if CharacterVoice.is_vowel(letter):
			_pending_vowel = CharacterVoice.vowel_for_letter(letter)
		_letters_since_syllable += 1
		if _letters_since_syllable >= syllable_every:
			_letters_since_syllable = 0
			_speak_syllable(letter)
	_label.visible_characters = now
	if now >= total:
		finish()

func _speak_syllable(letter: String) -> void:
	var vowel := _pending_vowel if not _pending_vowel.is_empty() else CharacterVoice.vowel_for_letter(letter)
	_pending_vowel = ""
	if not _voice_streams.has(vowel):
		return
	stream = _voice_streams[vowel]
	pitch_scale = randf_range(0.9, 1.12)
	play()
