class_name Synth
extends RefCounted
## Procedural sound toolkit. Every sound in the game is built from code as a
## PackedFloat32Array of samples in -1..1 at SAMPLE_RATE — no audio files ship.
## One-shots are rendered once and wrapped in an AudioStreamWAV (see
## SoundLibrary / the Sfx autoload); the running engine is synthesized live
## (see EngineSound).
##
## Curves are Arrays of [time_seconds, value] pairs, linearly interpolated and
## holding their first/last value outside the range.
##
## The sample loops run natively (SynthDsp in rust/). Native calls get their own
## copy of a packed array, so `mix_into` and `finish` copy the result back to
## keep changing the caller's array in place.

const SAMPLE_RATE := 22050

## Resonant band-pass (biquad). `tune()` then `step()` when the settings are
## fixed for a stretch; `process()` retunes every sample for sweeps.
class Formant:
	var b0 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func tune(frequency: float, q: float) -> void:
		var w := TAU * frequency / SAMPLE_RATE
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		b0 = alpha / a0
		a1 = -2.0 * cos(w) / a0
		a2 = (1.0 - alpha) / a0

	func step(x: float) -> float:
		var y := b0 * x - b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y

	func process(x: float, frequency: float, q: float) -> float:
		tune(frequency, q)
		return step(x)

## One-pole low-pass. Cheap and smooth.
class LowPass:
	var _y := 0.0
	var _a := 1.0

	func tune(cutoff: float) -> void:
		_a = Synth.one_pole_coefficient(cutoff)

	func step(x: float) -> float:
		_y += _a * (x - _y)
		return _y

	func process(x: float, cutoff: float) -> float:
		tune(cutoff)
		return step(x)

## One-pole high-pass (input minus its low-passed self).
class HighPass:
	var _low := LowPass.new()

	func tune(cutoff: float) -> void:
		_low.tune(cutoff)

	func step(x: float) -> float:
		return x - _low.step(x)

## Smoothing factor of a one-pole low-pass at `cutoff`.
static func one_pole_coefficient(cutoff: float) -> float:
	var w := TAU * cutoff / SAMPLE_RATE
	return w / (1.0 + w)

static func curve(points: Array, t: float) -> float:
	var first: Array = points[0]
	if t <= first[0]:
		return first[1]
	for i in range(1, points.size()):
		var p0: Array = points[i - 1]
		var p1: Array = points[i]
		if t <= p1[0]:
			return lerpf(p0[1], p1[1], (t - p0[0]) / (p1[0] - p0[0]))
	return points[-1][1]

## Soft saturation. 0 is clean, larger is squarer.
static func softclip(x: float, amount: float) -> float:
	if amount <= 0.0:
		return x
	return (1.0 + amount) * x / (1.0 + amount * absf(x))

static func sample_count(duration: float) -> int:
	return int(duration * SAMPLE_RATE)

static func silence(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(sample_count(duration))
	return out

static func concat(chunks: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for chunk: PackedFloat32Array in chunks:
		out.append_array(chunk)
	return out

## Mix `other` into `samples` starting at `offset_seconds`, scaled by `gain`.
static func mix_into(samples: PackedFloat32Array, other: PackedFloat32Array, offset_seconds: float = 0.0, gain: float = 1.0) -> PackedFloat32Array:
	_replace_contents(samples, SynthDsp.mixed(samples, other, sample_count(offset_seconds), gain))
	return samples

## Peak-normalise and add a tiny fade at both ends so nothing clicks. Loops
## pass `fade_time = 0` — a fade there would dip at every loop point.
static func finish(samples: PackedFloat32Array, peak: float = 0.85, fade_time: float = 0.005) -> PackedFloat32Array:
	_replace_contents(samples, SynthDsp.finished(samples, peak, fade_time))
	return samples

static func _replace_contents(target: PackedFloat32Array, source: PackedFloat32Array) -> void:
	target.clear()
	target.append_array(source)

## Piston voice: buzz source -> saturation -> low-pass -> optional body
## resonance -> amp envelope. Options (all optional except freq/amp/cutoff):
##   freq, amp, cutoff : curves
##   harmonics, rolloff : buzz brightness (more/lower = rougher)
##   sub : level of a sine an octave down (low-end thump)
##   noise, noise_cutoff : exhaust hiss mixed into the source
##   jitter, jitter_rate : random pitch wobble (roughness)
##   knock, knock_rate : slower random pitch wobble (big/diesel lope)
##   drive : saturation
##   resonance : [frequency, q, gain]
static func engine(duration: float, options: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	return SynthDsp.engine(duration, options, rng)

## One or more sine tones with their own pitch curves (horns, chimes, beeps).
## Options: amp (curve), square (0..1 squareness), tremolo ([rate, depth]).
static func tones(duration: float, frequency_curves: Array, options: Dictionary) -> PackedFloat32Array:
	return SynthDsp.tones(duration, frequency_curves, options)

## Band-passed noise with swept centre and Q (tyre squeal, skids, wind, hiss).
## Options: freq, q, amp (curves), highpass (Hz), lowpass (Hz).
static func noise_sweep(duration: float, options: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	return SynthDsp.noise_sweep(duration, options, rng)

## Short noise burst through a low-pass with a fast attack and exponential-ish
## decay — the building block for thumps, clunks and slams.
static func thump(duration: float, cutoff: float, attack: float, decay: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	return SynthDsp.thump(duration, cutoff, attack, decay, rng)

static func to_stream(samples: PackedFloat32Array, looping: bool = false) -> AudioStreamWAV:
	var bytes := SynthDsp.to_s16_bytes(samples)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
