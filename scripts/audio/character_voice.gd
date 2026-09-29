class_name CharacterVoice
extends RefCounted
## Gibberish speech for CharacterDialog: every character "talks" in short
## synthesized vowel syllables, picked from the vowels in the line being typed,
## so a line sounds like a garbled version of itself.
##
## A syllable is a buzzy sawtooth (the vocal cords) run through three resonant
## band-passes tuned to a vowel's formants (the mouth), with a tick of noise at
## the front standing in for a consonant. The CharacterData voice settings
## shape it: pitch, how big the throat is (formant scale), rasp and wobble.
## Each voice is rendered once, five syllables, and cached.

const VOWELS := ["a", "e", "i", "o", "u"]
## F1, F2, F3 in Hz for an average adult voice.
const VOWEL_FORMANTS := {
	"a": [730.0, 1090.0, 2440.0],
	"e": [530.0, 1840.0, 2480.0],
	"i": [270.0, 2290.0, 3010.0],
	"o": [570.0, 840.0, 2410.0],
	"u": [300.0, 870.0, 2240.0],
}
const FORMANT_BANDWIDTHS := [90.0, 110.0, 150.0]
const FORMANT_GAINS := [1.0, 0.65, 0.3]
const SYLLABLE_TIME := 0.085
const CONSONANT_TIME := 0.012

static var _cache: Dictionary = {}

## The five vowel syllables for `character`, as {"a": AudioStreamWAV, ...}.
static func streams_for(character: CharacterData) -> Dictionary:
	var settings := settings_for(character)
	var key := str(settings)
	if not _cache.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		var streams := {}
		for vowel in VOWELS:
			streams[vowel] = Synth.to_stream(_render_syllable(vowel, settings, rng))
		_cache[key] = streams
	return _cache[key]

## The character's own voice settings, or, for a character nobody has tuned
## yet, a voice derived from their name so no two sound alike by accident.
static func settings_for(character: CharacterData) -> Dictionary:
	if character != null and character.voice_pitch_hz > 0.0:
		return {
			pitch = character.voice_pitch_hz,
			throat = character.voice_throat,
			rasp = character.voice_rasp,
			wobble = character.voice_wobble,
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(character.display_name if character != null else "")
	return {
		pitch = rng.randf_range(90.0, 260.0),
		throat = rng.randf_range(0.85, 1.3),
		rasp = rng.randf_range(0.0, 0.5),
		wobble = rng.randf_range(0.0, 0.4),
	}

## Which syllable a typed letter should sound like: its own vowel if it is
## one, otherwise a fixed pick per consonant so words keep their rhythm.
static func vowel_for_letter(letter: String) -> String:
	var lower := letter.to_lower()
	match lower:
		"a", "e", "i", "o", "u":
			return lower
		"y":
			return "i"
		"w":
			return "u"
	return VOWELS[lower.unicode_at(0) % VOWELS.size()] if not lower.is_empty() else "a"

static func is_vowel(letter: String) -> bool:
	return "aeiouy".contains(letter.to_lower())

static func _render_syllable(vowel: String, settings: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var pitch: float = settings.pitch
	var throat: float = settings.throat
	var rasp: float = settings.rasp
	var wobble: float = settings.wobble

	var filters: Array[Synth.Formant] = []
	for i in 3:
		var filter := Synth.Formant.new()
		var frequency: float = minf(VOWEL_FORMANTS[vowel][i] * throat, Synth.SAMPLE_RATE * 0.45)
		filter.tune(frequency, frequency / FORMANT_BANDWIDTHS[i])
		filters.append(filter)
	var consonant_filter := Synth.HighPass.new()
	consonant_filter.tune(2500.0)

	var out := Synth.silence(SYLLABLE_TIME)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		var progress := t / SYLLABLE_TIME
		var frequency := pitch * (1.06 - 0.12 * progress) \
				* (1.0 + wobble * 0.09 * sin(TAU * 11.0 * t)) \
				* (1.0 + rasp * 0.04 * rng.randf_range(-1.0, 1.0))
		phase = fmod(phase + frequency / Synth.SAMPLE_RATE, 1.0)
		var source := 2.0 * phase - 1.0 + rasp * 0.7 * rng.randf_range(-1.0, 1.0)
		var voiced := 0.0
		for f in 3:
			voiced += filters[f].step(source) * FORMANT_GAINS[f]
		var envelope := minf(t / 0.01, 1.0) * minf((SYLLABLE_TIME - t) / 0.03, 1.0)
		var consonant := 0.0
		if t < CONSONANT_TIME:
			consonant = consonant_filter.step(rng.randf_range(-1.0, 1.0)) * (1.0 - t / CONSONANT_TIME) * 0.35
		out[i] = voiced * envelope + consonant
	return Synth.finish(out, 0.75)
