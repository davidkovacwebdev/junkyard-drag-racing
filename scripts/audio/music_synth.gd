class_name MusicSynth
extends RefCounted
## Renders one looping song from text patterns: a tiny sequencer plus a band of
## cheap, slightly broken instruments (slap bass, clavinet, kazoo, banjo, tuba,
## toy piano, slide whistle, combo organ, bloop, junk drums) and three
## not-quite-human singers (voice, gremlin, blob). The recipes live in
## scripts/audio/songs/; this plays them.
##
## Patterns are space-separated steps (`steps_per_beat` per beat, `|` is
## ignored and only there for reading):
##   `.`       rest
##   `-`       hold the previous note one more step
##   `C4`      a note (`F#3`, `Bb4` ...), `C4+E4` for several at once
##   `A4>D5`   bend from A4 to D5 over the note (kazoo, slap bass, tuba, whistle,
##             singers)
##   `G4@glup` a sung syllable (singers only; see `sing()`). Without one the
##             singer uses its default ("da", "nee", "bom").
##   drums, combinable with `+`:
##     `k` kick   `s` snare   `z` ghost snare   `c` clap   `h` hat
##     `o` open hat   `g` chicken-scratch guitar   `t` trash-can lid
##     `w` woodblock   `b` spring boing   `p` mouth pop   `q` squeaky toy
##     `n` saucepan bonk   `x` record scratch
## Chord-following helpers (`bass`, `strum`, `arpeggio`) take one chord name per
## bar (`G`, `Am`, `D7`, `F#m7`, `Bdim`) and a rhythm whose steps say which
## chord tone to play: `1` root, `3` third, `5` fifth, `7` seventh (octave when
## the chord has none), `8` octave, `x` the whole chord.
##
## Everything wraps around the song's end, so tails ring into the start and the
## result loops seamlessly. Tape edits (`stutter`, `tape_stop`, `reverse`,
## `dropout`, `crush`) are applied to the finished mix in `finish()`.
##
## The instruments, singers, drums and mix bus run natively (MusicDsp and
## SongMix in rust/); this file is the sequencer.

const SAMPLE_RATE := Synth.SAMPLE_RATE
const NOTE_OFFSETS := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const CHORD_INTERVALS := {
	"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10],
	"maj7": [0, 4, 7, 11], "dim": [0, 3, 6], "aug": [0, 4, 8], "6": [0, 4, 7, 9],
	"9": [0, 4, 10, 14], "7#9": [0, 4, 10, 15],
	"sus4": [0, 5, 7], "m6": [0, 3, 7, 9], "7b9": [0, 4, 10, 13], "aug7": [0, 4, 8, 10],
}
## Formants (F1, F2, F3 in Hz) of each sung vowel. Other vowel spellings glide
## from their first letter's vowel to their last ("ai", "ou", "oi").
const VOWELS := {
	"a": [780.0, 1250.0, 2500.0], "aa": [850.0, 1200.0, 2600.0], "e": [480.0, 1900.0, 2550.0],
	"i": [320.0, 2200.0, 2950.0], "ee": [270.0, 2350.0, 3050.0], "o": [480.0, 820.0, 2550.0],
	"oo": [300.0, 640.0, 2300.0], "u": [560.0, 1050.0, 2400.0], "y": [300.0, 2100.0, 2800.0],
}
## How each consonant sounds and where it pulls the formants from. Kinds:
## `stop` (silent closure then a noise burst), `voiced_stop` (hummed closure
## then a burst), `nasal`, `glide`, `fricative` (noise at `noise` Hz).
const CONSONANTS := {
	"b": {"kind": "voiced_stop", "locus": [220.0, 800.0, 2200.0], "noise": 700.0, "length": 0.04},
	"d": {"kind": "voiced_stop", "locus": [220.0, 1700.0, 2600.0], "noise": 3200.0, "length": 0.035},
	"g": {"kind": "voiced_stop", "locus": [220.0, 2000.0, 2300.0], "noise": 1900.0, "length": 0.04},
	"p": {"kind": "stop", "locus": [220.0, 800.0, 2200.0], "noise": 900.0, "length": 0.05},
	"t": {"kind": "stop", "locus": [220.0, 1700.0, 2600.0], "noise": 4200.0, "length": 0.045},
	"k": {"kind": "stop", "locus": [220.0, 2000.0, 2300.0], "noise": 2100.0, "length": 0.05},
	"m": {"kind": "nasal", "locus": [250.0, 900.0, 2200.0], "noise": 0.0, "length": 0.07},
	"n": {"kind": "nasal", "locus": [250.0, 1600.0, 2600.0], "noise": 0.0, "length": 0.06},
	"l": {"kind": "glide", "locus": [360.0, 1050.0, 2700.0], "noise": 0.0, "length": 0.05},
	"w": {"kind": "glide", "locus": [290.0, 600.0, 2200.0], "noise": 0.0, "length": 0.06},
	"r": {"kind": "glide", "locus": [360.0, 1150.0, 1550.0], "noise": 0.0, "length": 0.06},
	"j": {"kind": "glide", "locus": [270.0, 2300.0, 3000.0], "noise": 0.0, "length": 0.05},
	"h": {"kind": "fricative", "locus": [500.0, 1500.0, 2500.0], "noise": 1500.0, "length": 0.05},
	"s": {"kind": "fricative", "locus": [300.0, 1700.0, 2600.0], "noise": 6000.0, "length": 0.08},
	"z": {"kind": "fricative", "locus": [300.0, 1700.0, 2600.0], "noise": 5000.0, "length": 0.07},
	"f": {"kind": "fricative", "locus": [300.0, 900.0, 2300.0], "noise": 3500.0, "length": 0.07},
	"v": {"kind": "fricative", "locus": [300.0, 900.0, 2300.0], "noise": 3000.0, "length": 0.06},
	"sh": {"kind": "fricative", "locus": [300.0, 1900.0, 2600.0], "noise": 2600.0, "length": 0.08},
}
## The singers. `formant_shift` scales every formant (1 is a person, higher is a
## chipmunk, lower is a gargling giant), `fry` drops every other glottal pulse
## into a gloopy croak, `crack` is how often a long note yodels up an octave.
const SINGERS := {
	&"voice": {"formant_shift": 1.12, "vibrato_rate": 5.5, "vibrato_depth": 0.03, "jitter": 0.006,
			"breath": 0.06, "fry": 0.0, "scoop": -2.0, "crack": 0.35, "syllable": "da"},
	&"gremlin": {"formant_shift": 1.6, "vibrato_rate": 9.0, "vibrato_depth": 0.045, "jitter": 0.012,
			"breath": 0.12, "fry": 0.0, "scoop": 3.0, "crack": 0.0, "syllable": "nee"},
	&"blob": {"formant_shift": 0.7, "vibrato_rate": 3.5, "vibrato_depth": 0.02, "jitter": 0.01,
			"breath": 0.03, "fry": 0.55, "scoop": -5.0, "crack": 0.0, "syllable": "bom"},
}

var bpm: float
var beats_per_bar: int
var steps_per_beat: int
## 0..1: how late every second step lands. A little makes it shuffle.
var swing: float = 0.0
## Max random detune per note in cents. The "wonky" knob.
var detune_cents: float = 0.0
## Tape wobble on the whole mix: [depth in ms, cycles per song].
var tape_wow: Array = [0.0, 1]
## Semitones added to every pitched note played from now on — for a cheesy
## key change on the second pass without rewriting it.
var key_shift: int = 0
## Max random timing slop per hit in seconds — a band that isn't quite together.
var sloppiness: float = 0.0

var _mix: SongMix
var _rng := RandomNumberGenerator.new()
var _note_cache: Dictionary = {}
var _tape_edits: Array[Dictionary] = []

func _init(song_bpm: float, bar_count: int, song_beats_per_bar: int = 4, song_steps_per_beat: int = 2, seed_value: int = 0) -> void:
	bpm = song_bpm
	beats_per_bar = song_beats_per_bar
	steps_per_beat = song_steps_per_beat
	_rng.seed = seed_value
	_mix = SongMix.create(roundi(bar_count * beats_per_bar * 60.0 / bpm * SAMPLE_RATE))

func step_seconds() -> float:
	return 60.0 / bpm / steps_per_beat

func steps_per_bar() -> int:
	return beats_per_bar * steps_per_beat

# --- Sequencing ----------------------------------------------------------------

## Play a pattern on `instrument` starting at `bar` (0-based). Patterns longer
## than a bar run on into the following bars.
func play(instrument: StringName, pattern: String, bar: int, gain: float = 1.0, transpose: int = 0) -> void:
	_check_bar_lengths(pattern)
	var steps := _tokens(pattern)
	_play_steps(instrument, steps, bar * steps_per_bar(), steps.size(), gain, transpose)

## Sing `pattern` on a singer (`voice`, `gremlin`, `blob`), each note taking the
## next syllable of `lyrics` (space-separated, wraps around). Syllables are
## spelled as they sound: onset consonants, a vowel, an optional end consonant
## ("glup", "doo", "bwaa", "shmee", "hup", "blorp").
func sing(instrument: StringName, pattern: String, lyrics: String, bar: int, gain: float = 1.0, transpose: int = 0) -> void:
	var syllables := _tokens(lyrics)
	var sung := PackedStringArray()
	var syllable_index := 0
	for token in pattern.replace("|", " | ").split(" ", false):
		if token != "|" and token != "." and token != "-" and not token.contains("@"):
			token += "@" + syllables[syllable_index % syllables.size()]
			syllable_index += 1
		sung.append(token)
	play(instrument, " ".join(sung), bar, gain, transpose)

## Repeat `pattern` back to back for `bar_count` bars, ignoring bar lines: a
## 5-step figure over 4/4 keeps drifting against the beat (polymeter).
func loop(instrument: StringName, pattern: String, bar: int, bar_count: int, gain: float = 1.0, transpose: int = 0) -> void:
	_play_steps(instrument, _tokens(pattern), bar * steps_per_bar(), bar_count * steps_per_bar(), gain, transpose)

## Play the same riff once per entry in `transposes`, a bar-length apart — one
## riff walked through a chord sequence.
func riff(instrument: StringName, pattern: String, bar: int, transposes: Array, gain: float = 1.0) -> void:
	var riff_bars := maxi(1, ceili(float(_tokens(pattern).size()) / steps_per_bar()))
	for i in transposes.size():
		play(instrument, pattern, bar + i * riff_bars, gain, transposes[i])

## Bass line following `chords` (one per bar), repeating `rhythm` as needed.
func bass(instrument: StringName, chords: Array, rhythm: String, bar: int, gain: float = 1.0, octave: int = 2) -> void:
	_follow_chords(instrument, chords, rhythm, bar, gain, octave)

func strum(instrument: StringName, chords: Array, rhythm: String, bar: int, gain: float = 1.0, octave: int = 3) -> void:
	_follow_chords(instrument, chords, rhythm, bar, gain, octave)

func arpeggio(instrument: StringName, chords: Array, rhythm: String, bar: int, gain: float = 1.0, octave: int = 4) -> void:
	_follow_chords(instrument, chords, rhythm, bar, gain, octave)

## Same drum pattern repeated for `bar_count` bars.
func drums(pattern: String, bar: int, bar_count: int, gain: float = 1.0) -> void:
	var pattern_bars := maxi(1, ceili(float(_tokens(pattern).size()) / steps_per_bar()))
	for b in range(0, bar_count, pattern_bars):
		play(&"drums", pattern, bar + b, gain)

# --- Tape edits (applied to the whole mix in `finish()`, in order) -------------

## Grab `slice_steps` from `bar`/`step` and play it `repeats` times in a row, like
## a skipping CD.
func stutter(bar: int, step: int, slice_steps: int, repeats: int) -> void:
	_tape_edits.append({"kind": "stutter", "start": _sample_at(bar, step), "slice": _steps_to_samples(slice_steps), "repeats": repeats})

## The tape deck loses power: pitch and speed sag to nothing over `length_steps`.
func tape_stop(bar: int, step: int, length_steps: int) -> void:
	_tape_edits.append({"kind": "tape_stop", "start": _sample_at(bar, step), "length": _steps_to_samples(length_steps)})

## Play `length_steps` backwards.
func reverse(bar: int, step: int, length_steps: int) -> void:
	_tape_edits.append({"kind": "reverse", "start": _sample_at(bar, step), "length": _steps_to_samples(length_steps)})

## Someone kicked the cable out: silence for `length_steps`.
func dropout(bar: int, step: int, length_steps: int) -> void:
	_tape_edits.append({"kind": "dropout", "start": _sample_at(bar, step), "length": _steps_to_samples(length_steps)})

## Crunch `length_steps` down to a broken-radio bitcrush.
func crush(bar: int, step: int, length_steps: int) -> void:
	_tape_edits.append({"kind": "crush", "start": _sample_at(bar, step), "length": _steps_to_samples(length_steps)})

func _sample_at(bar: int, step: int) -> int:
	return _steps_to_samples(bar * steps_per_bar() + step)

func _steps_to_samples(steps: int) -> int:
	return roundi(steps * step_seconds() * SAMPLE_RATE)

## Master bus: tape edits, tape wobble, a little saturation, normalise, then
## cap the loudness so every song sits at the same level. Returns a stream that
## loops.
func finish() -> AudioStreamWAV:
	return Synth.to_stream(_mix.master(_tape_edits, tape_wow[0], tape_wow[1]), true)

func _play_steps(instrument: StringName, steps: PackedStringArray, first_step: int, step_count: int, gain: float, transpose: int) -> void:
	for i in step_count:
		var token: String = steps[i % steps.size()]
		if token == "." or token == "-":
			continue
		var held := 1
		while i + held < step_count and steps[(i + held) % steps.size()] == "-":
			held += 1
		_hit(instrument, token, first_step + i, held, gain, transpose)

func _follow_chords(instrument: StringName, chords: Array, rhythm: String, bar: int, gain: float, octave: int) -> void:
	var rhythm_steps := _tokens(rhythm)
	var step_count := chords.size() * steps_per_bar()
	var step := 0
	while step < step_count:
		var token: String = rhythm_steps[step % rhythm_steps.size()]
		if token != "." and token != "-":
			var held := 1
			while step + held < step_count and rhythm_steps[(step + held) % rhythm_steps.size()] == "-":
				held += 1
			var chord: String = chords[step / steps_per_bar()]
			var notes := _chord_tones(chord, token, octave)
			_hit(instrument, "+".join(notes), bar * steps_per_bar() + step, held, gain, 0)
		step += 1

func _hit(instrument: StringName, token: String, step_index: int, held_steps: int, gain: float, transpose: int) -> void:
	var start := step_index * step_seconds()
	if step_index % 2 == 1:
		start += swing * step_seconds() * 0.5
	var duration := held_steps * step_seconds()
	if instrument != &"drums":
		transpose += key_shift
	var variant := _rng.randi_range(0, 2)
	if sloppiness > 0.0:
		start = maxf(0.0, start + _rng.randf_range(-1.0, 1.0) * sloppiness)
	var key := "%s|%s|%d|%d|%d" % [instrument, token, held_steps, transpose, variant]
	var note: PackedFloat32Array = _note_cache.get(key, PackedFloat32Array())
	if note.is_empty():
		note = _render_note(instrument, token, duration, transpose, variant)
		_note_cache[key] = note
	_mix.mix_wrapped(note, roundi(start * SAMPLE_RATE), gain)

func _render_note(instrument: StringName, token: String, duration: float, transpose: int, variant: int) -> PackedFloat32Array:
	if instrument == &"drums":
		return MusicDsp.drum_hits(token.split("+"), _rng)
	var detune := pow(2.0, detune_cents * (variant - 1) / 1200.0)
	var syllable := ""
	if token.contains("@"):
		syllable = token.get_slice("@", 1)
		token = token.get_slice("@", 0)
	var names := token.split("+")
	var chord := PackedFloat32Array()
	for n in names.size():
		var ends := names[n].split(">")
		var from_frequency := _frequency(ends[0], transpose) * detune
		var to_frequency := _frequency(ends[-1], transpose) * detune
		var voice: PackedFloat32Array
		match instrument:
			&"kazoo": voice = MusicDsp.kazoo(from_frequency, to_frequency, duration, _rng)
			&"slap_bass": voice = MusicDsp.slap_bass(from_frequency, to_frequency, duration)
			&"clav": voice = MusicDsp.clav(from_frequency, duration)
			&"banjo": voice = MusicDsp.banjo(from_frequency, duration, _rng)
			&"tuba": voice = MusicDsp.tuba(from_frequency, to_frequency, duration)
			&"toy_piano": voice = MusicDsp.toy_piano(from_frequency, duration)
			&"whistle": voice = MusicDsp.slide_whistle(from_frequency, to_frequency, duration, _rng)
			&"organ": voice = MusicDsp.organ(from_frequency, duration, _rng)
			&"bloop": voice = MusicDsp.bloop(from_frequency, duration)
			&"voice", &"gremlin", &"blob":
				var singer: Dictionary = SINGERS[instrument]
				var parts := _split_syllable(syllable if syllable != "" else singer["syllable"])
				voice = MusicDsp.sing_note(from_frequency, to_frequency, duration, parts, CONSONANTS, singer, _rng)
			_:
				push_error("MusicSynth: unknown instrument '%s'" % instrument)
				return PackedFloat32Array()
		# Strummed, not struck: each string lands a hair after the last.
		Synth.mix_into(chord, voice, n * 0.012, 1.0 / sqrt(names.size()))
	return chord

## Every `|`-separated bar of a pattern must be exactly one bar long, or the
## rest of the pattern slides off the beat.
func _check_bar_lengths(pattern: String) -> void:
	for bar_text in pattern.split("|"):
		var length := _tokens(bar_text).size()
		if length != steps_per_bar():
			push_warning("MusicSynth: bar has %d steps, expected %d: '%s'" % [length, steps_per_bar(), bar_text.strip_edges()])

func _tokens(pattern: String) -> PackedStringArray:
	return pattern.replace("|", " ").split(" ", false)

func _frequency(note_name: String, transpose: int = 0) -> float:
	return 440.0 * pow(2.0, (_midi(note_name) + transpose - 69) / 12.0)

func _midi(note_name: String) -> int:
	var semitone: int = NOTE_OFFSETS[note_name[0]]
	var rest := note_name.substr(1)
	if rest.begins_with("#"):
		semitone += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		semitone -= 1
		rest = rest.substr(1)
	return (int(rest) + 1) * 12 + semitone

func _chord_tones(chord: String, degree: String, octave: int) -> PackedStringArray:
	var root_length := 2 if chord.length() > 1 and (chord[1] == "#" or chord[1] == "b") else 1
	var root := chord.substr(0, root_length)
	var intervals: Array = CHORD_INTERVALS[chord.substr(root_length)]
	var root_midi := _midi(root + str(octave))
	var picked: Array = []
	match degree:
		"1": picked = [0]
		"3": picked = [intervals[1]]
		"5": picked = [intervals[2]]
		"7": picked = [intervals[3] if intervals.size() > 3 else 12]
		"8": picked = [12]
		"x": picked = intervals
	var out := PackedStringArray()
	for interval: int in picked:
		out.append(_note_name(root_midi + interval))
	return out

func _note_name(midi: int) -> String:
	const NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	return "%s%d" % [NAMES[midi % 12], midi / 12 - 1]

# --- Singers ------------------------------------------------------------------

## "blorp" -> onset [b, l], vowel "o", coda [r, p]. Vowels come back as formant
## triples: `vowel_from` → `vowel_to` (the same for plain vowels, empty for a
## syllable that is all consonant like "mmm" or "shh").
static func _split_syllable(syllable: String) -> Dictionary:
	var letters := syllable.to_lower()
	var onset: Array[String] = []
	var coda: Array[String] = []
	var vowel := ""
	var i := 0
	while i < letters.length():
		var letter := letters[i]
		var is_vowel := "aeiou".contains(letter) or (letter == "y" and i > 0)
		if is_vowel and coda.is_empty():
			vowel += letter
			i += 1
			continue
		var consonant := letter
		if letters.substr(i, 2) == "sh":
			consonant = "sh"
		elif letter == "y":
			consonant = "j"
		elif letter == "c" or letter == "q" or letter == "x":
			consonant = "k"
		i += consonant.length() if consonant == "sh" else 1
		if not CONSONANTS.has(consonant):
			continue
		if vowel == "":
			onset.append(consonant)
		else:
			coda.append(consonant)
	var vowel_from: Array = []
	var vowel_to: Array = []
	if VOWELS.has(vowel):
		vowel_from = VOWELS[vowel]
		vowel_to = VOWELS[vowel]
	elif vowel != "":
		vowel_from = VOWELS.get(vowel[0], VOWELS["a"])
		vowel_to = VOWELS.get(vowel[-1], VOWELS["a"])
	elif onset.is_empty():
		vowel_from = VOWELS["a"]
		vowel_to = VOWELS["a"]
	return {"onset": onset, "coda": coda, "vowel_from": vowel_from, "vowel_to": vowel_to}
