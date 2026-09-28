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

const SAMPLE_RATE := Synth.SAMPLE_RATE
## RMS every song is brought down to.
const TARGET_LOUDNESS := 0.2
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

var _samples := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _note_cache: Dictionary = {}
var _tape_edits: Array[Dictionary] = []

func _init(song_bpm: float, bar_count: int, song_beats_per_bar: int = 4, song_steps_per_beat: int = 2, seed_value: int = 0) -> void:
	bpm = song_bpm
	beats_per_bar = song_beats_per_bar
	steps_per_beat = song_steps_per_beat
	_rng.seed = seed_value
	_samples.resize(roundi(bar_count * beats_per_bar * 60.0 / bpm * SAMPLE_RATE))

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

func _apply_tape_edits(input: PackedFloat32Array) -> PackedFloat32Array:
	var mix := input
	for edit in _tape_edits:
		var source := mix.duplicate()
		var length := mix.size()
		var start: int = edit["start"]
		match edit["kind"]:
			"stutter":
				var slice: int = edit["slice"]
				var total: int = slice * edit["repeats"]
				for i in total:
					var within := i % slice
					mix[(start + i) % length] = source[(start + within) % length] * _edge_gain(within, slice)
			"tape_stop":
				var span: int = edit["length"]
				var position := 0.0
				for i in span:
					var speed := pow(1.0 - float(i) / span, 1.6)
					var base := floori(position)
					var sample := lerpf(source[(start + base) % length], source[(start + base + 1) % length], position - base)
					mix[(start + i) % length] = sample * _edge_gain(i, span)
					position += speed
			"reverse":
				var span: int = edit["length"]
				for i in span:
					mix[(start + i) % length] = source[(start + span - 1 - i) % length] * _edge_gain(i, span)
			"dropout":
				var span: int = edit["length"]
				for i in span:
					mix[(start + i) % length] = source[(start + i) % length] * (1.0 - _edge_gain(i, span))
			"crush":
				var span: int = edit["length"]
				var held := 0.0
				for i in span:
					if i % 6 == 0:
						held = roundf(source[(start + i) % length] * 6.0) / 6.0
					var gain := _edge_gain(i, span)
					mix[(start + i) % length] = held * gain + source[(start + i) % length] * (1.0 - gain)
	return mix

## Short fades at both ends of an edited stretch so the splices don't click.
static func _edge_gain(index: int, span: int) -> float:
	const FADE := 60.0
	return clampf(minf(index / FADE, (span - 1 - index) / FADE), 0.0, 1.0)

## Master bus: tape wobble, a little saturation, normalise, then cap the
## loudness so every song sits at the same level. Returns a stream that loops.
func finish() -> AudioStreamWAV:
	var mixed := _apply_tape_wow(_apply_tape_edits(_samples))
	for i in mixed.size():
		mixed[i] = Synth.softclip(mixed[i], 0.6)
	Synth.finish(mixed, 0.8, 0.0)
	var power := 0.0
	for sample in mixed:
		power += sample * sample
	var loudness := sqrt(power / maxi(mixed.size(), 1))
	if loudness > TARGET_LOUDNESS:
		for i in mixed.size():
			mixed[i] *= TARGET_LOUDNESS / loudness
	return Synth.to_stream(mixed, true)

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
	_mix_wrapped(note, roundi(start * SAMPLE_RATE), gain)

func _render_note(instrument: StringName, token: String, duration: float, transpose: int, variant: int) -> PackedFloat32Array:
	if instrument == &"drums":
		return _drum_hits(token.split("+"))
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
			&"kazoo": voice = kazoo(from_frequency, to_frequency, duration)
			&"slap_bass": voice = slap_bass(from_frequency, to_frequency, duration)
			&"clav": voice = clav(from_frequency, duration)
			&"banjo": voice = banjo(from_frequency, duration)
			&"tuba": voice = tuba(from_frequency, to_frequency, duration)
			&"toy_piano": voice = toy_piano(from_frequency, duration)
			&"whistle": voice = slide_whistle(from_frequency, to_frequency, duration)
			&"organ": voice = organ(from_frequency, duration)
			&"bloop": voice = bloop(from_frequency, duration)
			&"voice", &"gremlin", &"blob":
				var singer: Dictionary = SINGERS[instrument]
				voice = sing_note(from_frequency, to_frequency, duration, syllable if syllable != "" else singer["syllable"], singer, variant)
			_:
				push_error("MusicSynth: unknown instrument '%s'" % instrument)
				return PackedFloat32Array()
		# Strummed, not struck: each string lands a hair after the last.
		Synth.mix_into(chord, voice, n * 0.012, 1.0 / sqrt(names.size()))
	return chord

func _mix_wrapped(note: PackedFloat32Array, offset: int, gain: float) -> void:
	var length := _samples.size()
	for i in note.size():
		var index := (offset + i) % length
		_samples[index] += note[i] * gain

## Variable delay read with a sine that fits whole cycles in the song, so the
## wobble is seamless across the loop point.
func _apply_tape_wow(input: PackedFloat32Array) -> PackedFloat32Array:
	var depth: float = tape_wow[0] * 0.001 * SAMPLE_RATE
	if depth <= 0.0:
		return input
	var length := input.size()
	var cycles: float = tape_wow[1]
	var out := PackedFloat32Array()
	out.resize(length)
	for i in length:
		var delay := depth * (1.0 + sin(TAU * cycles * i / length)) * 0.5
		var position := i - delay
		var base := floori(position)
		var fraction := position - base
		out[i] = lerpf(input[posmod(base, length)], input[posmod(base + 1, length)], fraction)
	return out

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

# --- Instruments --------------------------------------------------------------
# Each returns mono samples: the held note plus its release tail.

## Buzzy comb-and-paper kazoo: a saw scooping up into the pitch, wobbling
## vibrato, pushed through two vowel formants with a bit of breath.
func kazoo(from_frequency: float, to_frequency: float, duration: float) -> PackedFloat32Array:
	var release := 0.05
	var out := Synth.silence(duration + release)
	var low_formant := Synth.Formant.new()
	var high_formant := Synth.Formant.new()
	low_formant.tune(650.0, 3.0)
	high_formant.tune(1700.0, 4.0)
	var breath := Synth.LowPass.new()
	breath.tune(3000.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var frequency := _glide(from_frequency, to_frequency, t, duration)
		var scoop := 1.0 - 0.06 * maxf(0.0, 1.0 - t / 0.04)
		var vibrato := 1.0 + 0.015 * sin(TAU * 6.0 * t) * minf(1.0, t / 0.2)
		phase = fmod(phase + frequency * scoop * vibrato / SAMPLE_RATE, 1.0)
		var saw := 2.0 * phase - 1.0 + breath.step(_rng.randf_range(-1.0, 1.0)) * 0.15
		var voiced := low_formant.step(saw) * 1.2 + high_formant.step(saw) * 0.8 + saw * 0.15
		out[i] = Synth.softclip(voiced, 1.5) * _envelope(t, 0.012, duration, release)
	return out

## Funk slap bass: a saw/square through a resonant low-pass that snaps shut
## after the pluck ("pew"), with a thumb-pop click on top.
func slap_bass(from_frequency: float, to_frequency: float, duration: float) -> PackedFloat32Array:
	var release := 0.04
	var held := minf(duration, 0.7)
	var out := Synth.silence(held + release)
	var low := 0.0
	var band := 0.0
	var damping := 0.25
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var frequency := _glide(from_frequency, to_frequency, t, duration)
		phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
		var source := (2.0 * phase - 1.0) * 0.6 + (1.0 if phase < 0.5 else -1.0) * 0.4
		var cutoff := 250.0 + 2600.0 * exp(-t * 22.0)
		var coefficient := 2.0 * sin(PI * cutoff / SAMPLE_RATE)
		low += coefficient * band
		var high := source - low - damping * band
		band += coefficient * high
		var pop := sin(TAU * 1800.0 * t) * exp(-t * 180.0) * 0.5
		out[i] = Synth.softclip(low * 0.9 + pop, 0.8) * _envelope(t, 0.002, held, release)
	return out

## Clavinet: a thin pulse wave through a filter that quacks open and shut.
## Short and choppy — made for off-beat stabs.
func clav(frequency: float, duration: float) -> PackedFloat32Array:
	var held := minf(duration, 0.25)
	var release := 0.03
	var out := Synth.silence(held + release)
	var low := 0.0
	var band := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
		var pulse := 1.0 if phase < 0.22 else -0.3
		var cutoff := minf(3400.0, 700.0 + 3200.0 * exp(-t * 30.0))
		var coefficient := 2.0 * sin(PI * cutoff / SAMPLE_RATE)
		low += coefficient * band
		var high := pulse - low - 0.18 * band
		band += coefficient * high
		out[i] = (band * 0.7 + low * 0.3) * exp(-t * 6.0) * _envelope(t, 0.001, held, release)
	return out

## Karplus-Strong plucked string: bright twang, quick decay, choked off when the
## note ends.
func banjo(frequency: float, duration: float) -> PackedFloat32Array:
	var ring := minf(duration, 0.6) + 0.06
	var out := Synth.silence(ring)
	var period := maxi(2, roundi(SAMPLE_RATE / frequency))
	var delay_line := PackedFloat32Array()
	delay_line.resize(period)
	for i in period:
		delay_line[i] = _rng.randf_range(-1.0, 1.0)
	var index := 0
	var previous := 0.0
	for i in out.size():
		var current := delay_line[index]
		delay_line[index] = (current + previous) * 0.5 * 0.994
		previous = current
		index = (index + 1) % period
		var t := float(i) / SAMPLE_RATE
		var choke := clampf(1.0 - (t - (ring - 0.06)) / 0.06, 0.0, 1.0)
		out[i] = current * choke * 0.8
	return out

## Oom-pah tuba: a few rounded harmonics, a little "blat" on the attack.
func tuba(from_frequency: float, to_frequency: float, duration: float) -> PackedFloat32Array:
	var release := 0.08
	var held := minf(duration, 0.6)
	var out := Synth.silence(held + release)
	var lowpass := Synth.LowPass.new()
	lowpass.tune(700.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var blat := 1.0 + 0.03 * maxf(0.0, 1.0 - t / 0.04)
		phase += _glide(from_frequency, to_frequency, t, duration) * blat / SAMPLE_RATE
		var tone := sin(TAU * phase) + 0.5 * sin(TAU * 2.0 * phase) + 0.3 * sin(TAU * 3.0 * phase)
		var bright := 1.0 + 1.5 * maxf(0.0, 1.0 - t / 0.06)
		out[i] = lowpass.step(Synth.softclip(tone * bright, 0.8)) * _envelope(t, 0.015, held, release)
	return out

## Plinky toy piano: a sine plus a clanky out-of-tune partial, both dying fast.
func toy_piano(frequency: float, duration: float) -> PackedFloat32Array:
	var length := minf(duration, 0.4) + 0.4
	var out := Synth.silence(length)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var body := sin(TAU * frequency * t) * exp(-t * 5.0)
		var tine := sin(TAU * frequency * 3.87 * t) * exp(-t * 18.0) * 0.5
		var click := sin(TAU * frequency * 7.1 * t) * exp(-t * 60.0) * 0.3
		out[i] = (body + tine + click) * minf(1.0, t / 0.002) * minf(1.0, (length - t) / 0.05)
	return out

## Swanee whistle glide between two pitches, breathy and a bit wobbly.
func slide_whistle(from_frequency: float, to_frequency: float, duration: float) -> PackedFloat32Array:
	var release := 0.05
	var out := Synth.silence(duration + release)
	var breath := Synth.Formant.new()
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var frequency := _glide(from_frequency, to_frequency, t, duration)
		frequency *= 1.0 + 0.01 * sin(TAU * 6.0 * t)
		phase += frequency / SAMPLE_RATE
		var hiss := breath.process(_rng.randf_range(-1.0, 1.0), frequency, 8.0) * 0.4
		out[i] = (sin(TAU * phase) + hiss) * _envelope(t, 0.03, duration, release)
	return out

## Cheesy combo organ: two detuned pulse waves and an octave sine, wobbling
## through a cheap tremolo. For chords that shouldn't go together.
func organ(frequency: float, duration: float) -> PackedFloat32Array:
	var release := 0.05
	var out := Synth.silence(duration + release)
	var lowpass := Synth.LowPass.new()
	lowpass.tune(2400.0)
	var phase_a := _rng.randf()
	var phase_b := _rng.randf()
	var phase_octave := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		phase_a = fmod(phase_a + frequency / SAMPLE_RATE, 1.0)
		phase_b = fmod(phase_b + frequency * 1.008 / SAMPLE_RATE, 1.0)
		phase_octave = fmod(phase_octave + frequency * 2.0 / SAMPLE_RATE, 1.0)
		var pulses := (1.0 if phase_a < 0.4 else -1.0) * 0.4 + (1.0 if phase_b < 0.5 else -1.0) * 0.4
		var tremolo := 1.0 + 0.3 * sin(TAU * 6.3 * t)
		var tone := lowpass.step(pulses) + sin(TAU * phase_octave) * 0.3
		out[i] = tone * tremolo * _envelope(t, 0.008, duration, release)
	return out

## A fat water drop: a sine that swoops up into its pitch with a wet wobble.
## The "glup".
func bloop(frequency: float, duration: float) -> PackedFloat32Array:
	var length := minf(duration, 0.35) + 0.1
	var out := Synth.silence(length)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var swoop := 1.0 - 0.5 * exp(-t * 26.0)
		var wobble := 1.0 + 0.06 * sin(TAU * 13.0 * t) * exp(-t * 5.0)
		phase += frequency * swoop * wobble / SAMPLE_RATE
		var tone := sin(TAU * phase) + 0.25 * sin(TAU * 2.0 * phase) * exp(-t * 12.0)
		out[i] = tone * exp(-t * 6.5) * minf(1.0, t / 0.004) * minf(1.0, (length - t) / 0.03)
	return out

## A not-quite-human singer: a glottal buzz through three moving vowel formants,
## with consonants built from noise bursts, hums and formant swoops. `singer` is
## an entry of SINGERS.
func sing_note(from_frequency: float, to_frequency: float, duration: float, syllable: String, singer: Dictionary, variant: int) -> PackedFloat32Array:
	var release := 0.07
	var out := Synth.silence(duration + release)
	var parts := _split_syllable(syllable)
	var onset: Array = parts["onset"]
	var coda: Array = parts["coda"]
	var vowel_from: Array = parts["vowel_from"]
	var vowel_to: Array = parts["vowel_to"]
	var sustained_consonant := vowel_from.is_empty()

	var onset_lengths: Array[float] = []
	var onset_total := 0.0
	for letter: String in onset:
		onset_lengths.append(CONSONANTS[letter]["length"])
		onset_total += CONSONANTS[letter]["length"]
	var onset_scale := minf(1.0, minf(duration * 0.4, 0.15) / maxf(onset_total, 0.001))
	if sustained_consonant and not onset.is_empty():
		onset_lengths[-1] += duration - onset_total * onset_scale
	var vowel_start := onset_total * onset_scale if not sustained_consonant else duration
	var coda_length := minf(0.08, duration * 0.3) if not coda.is_empty() else 0.0
	var coda_start := duration - coda_length
	var last_locus: Array = CONSONANTS[onset[-1]]["locus"] if not onset.is_empty() else vowel_from

	var shift: float = singer["formant_shift"]
	var formant_filters: Array[Synth.Formant] = [Synth.Formant.new(), Synth.Formant.new(), Synth.Formant.new()]
	const FORMANT_BANDWIDTHS := [90.0, 110.0, 150.0]
	const FORMANT_GAINS := [1.0, 0.6, 0.35]
	var noise_filter := Synth.Formant.new()
	var nasal_filter := Synth.LowPass.new()
	nasal_filter.tune(350.0 * shift)
	var jitter_filter := Synth.LowPass.new()
	jitter_filter.tune(18.0)
	var jitter_gain := Synth.lowpass_noise_gain(18.0)
	var cracks: bool = duration >= 0.3 and _rng.randf() < singer["crack"]
	var crack_time := duration * 0.55

	var formants := [0.0, 0.0, 0.0]
	var target: Array = last_locus
	for f in 3:
		formants[f] = last_locus[f] * shift
	var voicing := 0.0
	var nasal := 0.0
	var phase := 0.0
	var pulse_index := 0
	var previous_flow := 0.0
	var previous_excitation := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var frequency := _glide(from_frequency, to_frequency, t, duration)
		frequency *= pow(2.0, singer["scoop"] / 12.0 * maxf(0.0, 1.0 - t / 0.09))
		var vibrato_amount := clampf((t - 0.15) / 0.3, 0.0, 1.0)
		frequency *= 1.0 + singer["vibrato_depth"] * vibrato_amount * sin(TAU * singer["vibrato_rate"] * t)
		frequency *= 1.0 + singer["jitter"] * jitter_filter.step(_rng.randf_range(-1.0, 1.0)) * jitter_gain
		if cracks and t > crack_time and t < crack_time + 0.09:
			frequency *= 2.0

		# What the mouth is doing right now.
		var voicing_target := 1.0
		var nasal_target := 0.0
		var noise_amount := 0.0
		var noise_frequency := 2000.0
		if t < vowel_start or sustained_consonant:
			var letter_start := 0.0
			var letter_index := 0
			while letter_index < onset.size() - 1 and t >= letter_start + onset_lengths[letter_index] * onset_scale:
				letter_start += onset_lengths[letter_index] * onset_scale
				letter_index += 1
			var consonant: Dictionary = CONSONANTS[onset[letter_index]]
			var letter_length: float = onset_lengths[letter_index] * onset_scale
			var progress := (t - letter_start) / maxf(letter_length, 0.001)
			target = consonant["locus"]
			noise_frequency = consonant["noise"]
			match consonant["kind"]:
				"stop":
					voicing_target = 0.0
					noise_amount = exp(-(progress - 0.7) * 12.0) if progress > 0.7 else 0.0
				"voiced_stop":
					voicing_target = 0.2 if progress < 0.75 else 1.0
					nasal_target = 1.0 if progress < 0.75 else 0.0
					noise_amount = exp(-(progress - 0.75) * 14.0) * 0.6 if progress > 0.75 else 0.0
				"nasal":
					nasal_target = 1.0
				"fricative":
					voicing_target = 0.35 if onset[letter_index] in ["z", "v"] else 0.0
					noise_amount = 0.5
		elif t < coda_start or coda.is_empty():
			var into_vowel := smoothstep(vowel_start, coda_start, t)
			var settle := minf(1.0, (t - vowel_start) / 0.05)
			target = []
			for f in 3:
				var vowel_formant := lerpf(vowel_from[f], vowel_to[f], smoothstep(0.15, 0.9, into_vowel))
				target.append(lerpf(last_locus[f], vowel_formant, settle))
		else:
			var progress := (t - coda_start) / maxf(coda_length, 0.001)
			var letter: String = coda[mini(int(progress * coda.size()), coda.size() - 1)]
			var consonant: Dictionary = CONSONANTS[letter]
			target = consonant["locus"]
			noise_frequency = consonant["noise"]
			match consonant["kind"]:
				"stop", "voiced_stop":
					voicing_target = 0.0 if progress > 0.4 else 1.0
					noise_amount = exp(-(progress - 0.75) * 10.0) * 0.5 if progress > 0.75 else 0.0
				"nasal":
					nasal_target = 1.0
				"fricative":
					voicing_target = 0.0
					noise_amount = 0.45
		if t > duration:
			voicing_target = 0.0
			noise_amount = 0.0

		voicing += (voicing_target - voicing) * 0.02
		nasal += (nasal_target - nasal) * 0.01
		for f in 3:
			formants[f] += (target[f] * shift - formants[f]) * 0.004
		if i % 8 == 0:
			for f in 3:
				formant_filters[f].tune(formants[f], maxf(2.0, formants[f] / (FORMANT_BANDWIDTHS[f] * shift)))

		phase += frequency / SAMPLE_RATE
		if phase >= 1.0:
			phase -= 1.0
			pulse_index += 1
		var flow := _glottal_flow(phase)
		var pulse := (flow - previous_flow) * SAMPLE_RATE / (frequency * 6.0)
		previous_flow = flow
		if pulse_index % 2 == 1:
			pulse *= 1.0 - singer["fry"]
		var raw_excitation: float = (pulse + _rng.randf_range(-1.0, 1.0) * singer["breath"]) * voicing
		# Pre-emphasis, or the upper formants drown and every vowel sounds like "uh".
		var excitation := raw_excitation - 0.94 * previous_excitation
		previous_excitation = raw_excitation
		var tract := 0.0
		for f in 3:
			tract += formant_filters[f].step(excitation) * FORMANT_GAINS[f]
		var hum := nasal_filter.step(excitation) * 1.5
		var hiss := 0.0
		if noise_amount > 0.0:
			hiss = noise_filter.process(_rng.randf_range(-1.0, 1.0), noise_frequency, 2.5) * noise_amount
		var sample := lerpf(tract * 3.0, hum, nasal) + hiss
		out[i] = Synth.softclip(sample, 0.6) * _envelope(t, 0.006, duration, release)
	return Synth.finish(out, 0.8, 0.0)

## Rosenberg glottal pulse: the puff of air through the vocal folds each cycle.
static func _glottal_flow(phase: float) -> float:
	if phase < 0.4:
		return 0.5 * (1.0 - cos(PI * phase / 0.4))
	if phase < 0.56:
		return cos(0.5 * PI * (phase - 0.4) / 0.16)
	return 0.0

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

func _drum_hits(names: PackedStringArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for drum_name in names:
		match drum_name:
			"k": Synth.mix_into(out, _kick(), 0.0, 1.0)
			"s": Synth.mix_into(out, _snare(), 0.0, 0.6)
			"z": Synth.mix_into(out, _snare(), 0.0, 0.15)
			"c": Synth.mix_into(out, _clap(), 0.0, 0.5)
			"h": Synth.mix_into(out, _hat(0.05), 0.0, 0.22)
			"o": Synth.mix_into(out, _hat(0.25), 0.0, 0.2)
			"g": Synth.mix_into(out, _chicken_scratch(), 0.0, 0.35)
			"t": Synth.mix_into(out, _trash_lid(), 0.0, 0.35)
			"w": Synth.mix_into(out, _woodblock(), 0.0, 0.5)
			"b": Synth.mix_into(out, _boing(), 0.0, 0.45)
			"p": Synth.mix_into(out, _mouth_pop(), 0.0, 0.5)
			"q": Synth.mix_into(out, _squeaky_toy(), 0.0, 0.3)
			"n": Synth.mix_into(out, _saucepan_bonk(), 0.0, 0.45)
			"x": Synth.mix_into(out, _record_scratch(), 0.0, 0.35)
	return out

func _kick() -> PackedFloat32Array:
	var out := Synth.silence(0.3)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		phase += lerpf(45.0, 150.0, exp(-t * 30.0)) / SAMPLE_RATE
		out[i] = sin(TAU * phase) * exp(-t * 12.0)
	return out

## A cardboard-box snare: a dull tonk under a burst of noise.
func _snare() -> PackedFloat32Array:
	var out := Synth.silence(0.18)
	var highpass := Synth.HighPass.new()
	highpass.tune(1200.0)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var noise := highpass.step(_rng.randf_range(-1.0, 1.0)) * exp(-t * 22.0)
		var tonk := sin(TAU * 185.0 * t) * exp(-t * 30.0)
		out[i] = noise + tonk * 0.6
	return out

## Three smeared noise slaps, like a handful of people who can't quite clap
## together.
func _clap() -> PackedFloat32Array:
	var out := Synth.silence(0.2)
	var band := Synth.Formant.new()
	band.tune(1300.0, 1.5)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-fmod(t, 0.011) * 300.0) if t < 0.033 else exp(-(t - 0.033) * 25.0)
		out[i] = band.step(_rng.randf_range(-1.0, 1.0)) * envelope * 3.0
	return out

func _hat(length: float) -> PackedFloat32Array:
	var out := Synth.silence(length)
	var highpass := Synth.HighPass.new()
	highpass.tune(5000.0)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		out[i] = highpass.step(_rng.randf_range(-1.0, 1.0)) * exp(-t * 4.0 / length)
	return out

## Muted guitar strings raked with a pick — the funk "chk".
func _chicken_scratch() -> PackedFloat32Array:
	var out := Synth.silence(0.045)
	var band := Synth.Formant.new()
	band.tune(2400.0, 2.0)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var body := sin(TAU * 330.0 * t) * 0.3
		out[i] = (band.step(_rng.randf_range(-1.0, 1.0)) * 3.0 + body) * exp(-t * 70.0)
	return out

## Hitting a bin lid with a spanner: two clashing metal modes ringing out.
func _trash_lid() -> PackedFloat32Array:
	var out := Synth.silence(0.4)
	var ring_low := Synth.Formant.new()
	var ring_high := Synth.Formant.new()
	ring_low.tune(1830.0, 40.0)
	ring_high.tune(2710.0, 50.0)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var strike := _rng.randf_range(-1.0, 1.0) * exp(-t * 200.0)
		out[i] = (ring_low.step(strike) * 6.0 + ring_high.step(strike) * 5.0 + strike * 0.3) * exp(-t * 7.0)
	return out

func _woodblock() -> PackedFloat32Array:
	var out := Synth.silence(0.08)
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		out[i] = (sin(TAU * 880.0 * t) + 0.4 * sin(TAU * 1370.0 * t)) * exp(-t * 55.0)
	return out

## Cartoon door-stop spring: a rising tone with a fast wobble that dies off.
func _boing() -> PackedFloat32Array:
	var out := Synth.silence(0.6)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var frequency := 160.0 * (1.0 + 0.8 * t) * (1.0 + 0.25 * sin(TAU * 17.0 * t) * exp(-t * 3.0))
		phase += frequency / SAMPLE_RATE
		out[i] = Synth.softclip(sin(TAU * phase), 1.0) * exp(-t * 5.0) * minf(1.0, t / 0.003)
	return out

## Finger flicked out of a cheek: a quick hollow "pok" that drops in pitch.
func _mouth_pop() -> PackedFloat32Array:
	var out := Synth.silence(0.09)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		phase += lerpf(220.0, 620.0, exp(-t * 60.0)) / SAMPLE_RATE
		out[i] = sin(TAU * phase) * exp(-t * 45.0) * minf(1.0, t / 0.001)
	return out

## Dog toy squeezed twice: "wee-eek".
func _squeaky_toy() -> PackedFloat32Array:
	var out := Synth.silence(0.22)
	var squeal := Synth.Formant.new()
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var frequency := 1700.0 + 900.0 * sin(PI * minf(t / 0.2, 1.0)) + 150.0 * sin(TAU * 38.0 * t)
		phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
		var reed := 2.0 * phase - 1.0
		var envelope := minf(1.0, t / 0.01) * minf(1.0, (0.22 - t) / 0.03) * (0.6 + 0.4 * sin(TAU * 11.0 * t))
		out[i] = squeal.process(reed, frequency * 1.5, 3.0) * 2.0 * envelope
	return out

## A wooden spoon on an upturned saucepan: a bright clang that bends down.
func _saucepan_bonk() -> PackedFloat32Array:
	var out := Synth.silence(0.35)
	var phase_low := 0.0
	var phase_high := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var bend := 1.0 + 0.3 * exp(-t * 40.0)
		phase_low += 540.0 * bend / SAMPLE_RATE
		phase_high += 1290.0 * bend / SAMPLE_RATE
		out[i] = (sin(TAU * phase_low) * exp(-t * 11.0) + 0.5 * sin(TAU * phase_high) * exp(-t * 18.0)) * minf(1.0, t / 0.001)
	return out

## A DJ dragging a record back and forth: noisy tone that swoops down and up.
func _record_scratch() -> PackedFloat32Array:
	var out := Synth.silence(0.25)
	var band := Synth.Formant.new()
	var phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var speed := sin(PI * t / 0.25 * 2.0)
		var frequency := 180.0 + 1400.0 * absf(speed)
		phase = fmod(phase + frequency / SAMPLE_RATE, 1.0)
		var grit := band.process(_rng.randf_range(-1.0, 1.0), frequency * 2.0, 4.0) * 1.5
		out[i] = ((2.0 * phase - 1.0) * 0.4 + grit) * absf(speed) * minf(1.0, (0.25 - t) / 0.02)
	return out

## Exponential pitch bend across the whole note.
static func _glide(from_frequency: float, to_frequency: float, t: float, duration: float) -> float:
	if from_frequency == to_frequency:
		return from_frequency
	return from_frequency * pow(to_frequency / from_frequency, smoothstep(0.0, duration, t))

## Attack ramp, hold for `held`, then a linear release.
static func _envelope(t: float, attack: float, held: float, release: float) -> float:
	if t < attack:
		return t / attack
	if t < held:
		return 1.0
	return maxf(0.0, 1.0 - (t - held) / release)
