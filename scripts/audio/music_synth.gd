class_name MusicSynth
extends RefCounted
## Renders one looping song from text patterns: a tiny sequencer plus a band of
## cheap, slightly broken instruments (slap bass, clavinet, kazoo, banjo, tuba,
## toy piano, slide whistle, junk drums). SongLibrary writes the songs; this
## plays them.
##
## Patterns are space-separated steps (`steps_per_beat` per beat, `|` is
## ignored and only there for reading):
##   `.`       rest
##   `-`       hold the previous note one more step
##   `C4`      a note (`F#3`, `Bb4` ...), `C4+E4` for several at once
##   `A4>D5`   bend from A4 to D5 over the note (kazoo, slap bass, tuba, whistle)
##   drums, combinable with `+`:
##     `k` kick   `s` snare   `z` ghost snare   `c` clap   `h` hat
##     `o` open hat   `g` chicken-scratch guitar   `t` trash-can lid
##     `w` woodblock   `b` spring boing
## Chord-following helpers (`bass`, `strum`, `arpeggio`) take one chord name per
## bar (`G`, `Am`, `D7`, `F#m7`, `Bdim`) and a rhythm whose steps say which
## chord tone to play: `1` root, `3` third, `5` fifth, `7` seventh (octave when
## the chord has none), `8` octave, `x` the whole chord.
##
## Everything wraps around the song's end, so tails ring into the start and the
## result loops seamlessly.

const SAMPLE_RATE := Synth.SAMPLE_RATE
## RMS every song is brought down to.
const TARGET_LOUDNESS := 0.2
const NOTE_OFFSETS := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const CHORD_INTERVALS := {
	"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10],
	"maj7": [0, 4, 7, 11], "dim": [0, 3, 6], "aug": [0, 4, 8], "6": [0, 4, 7, 9],
	"9": [0, 4, 10, 14], "7#9": [0, 4, 10, 15],
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

var _samples := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _note_cache: Dictionary = {}

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
	for i in steps.size():
		var token: String = steps[i]
		if token == "." or token == "-":
			continue
		var held := 1
		while i + held < steps.size() and steps[i + held] == "-":
			held += 1
		_hit(instrument, token, bar * steps_per_bar() + i, held, gain, transpose)

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

## Master bus: tape wobble, a little saturation, normalise, then cap the
## loudness so every song sits at the same level. Returns a stream that loops.
func finish() -> AudioStreamWAV:
	var mixed := _apply_tape_wow(_samples)
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
