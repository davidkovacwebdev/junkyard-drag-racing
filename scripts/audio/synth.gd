class_name Synth
extends RefCounted
## Procedural sound toolkit. Every sound in the game is built from code as a
## PackedFloat32Array of samples in -1..1 at SAMPLE_RATE — no audio files ship.
## One-shots are rendered once and wrapped in an AudioStreamWAV (see
## SoundLibrary / the Sfx autoload); the running engine uses the same filters
## live (see EngineSound).
##
## Curves are Arrays of [time_seconds, value] pairs, linearly interpolated and
## holding their first/last value outside the range.

const SAMPLE_RATE := 22050

## Resonant band-pass (biquad). `tune()` then `step()` when the settings are
## fixed for a stretch; `process()` retunes every sample for sweeps.
class Formant:
	## Coefficients are public so a hot loop can inline the filter (EngineSound).
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

## Smoothing factor of a one-pole low-pass at `cutoff`. Exposed so hot loops
## (EngineSound) can inline the filter instead of calling `LowPass.step()`.
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

## Additive band-limited "buzz": harmonics of `frequency` at 1/k^rolloff. The
## stand-in for an engine's firing pulse.
static func buzz(phase: float, frequency: float, max_harmonics: int, rolloff: float) -> float:
	var count := mini(max_harmonics, int((SAMPLE_RATE / 2.0 - 200.0) / frequency))
	var sum := 0.0
	for k in range(1, count + 1):
		sum += sin(TAU * k * phase) / pow(k, rolloff)
	return sum

## Soft saturation. 0 is clean, larger is squarer.
static func softclip(x: float, amount: float) -> float:
	if amount <= 0.0:
		return x
	return (1.0 + amount) * x / (1.0 + amount * absf(x))

## Gain that gives low-passed white noise roughly unit deviation, so a jitter
## or knock depth means the same thing whatever its rate.
static func lowpass_noise_gain(cutoff: float) -> float:
	var a := one_pole_coefficient(cutoff)
	return 1.0 / sqrt(a / (2.0 - a) / 3.0)

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
	var offset := sample_count(offset_seconds)
	if samples.size() < offset + other.size():
		samples.resize(offset + other.size())
	for i in other.size():
		samples[offset + i] += other[i] * gain
	return samples

## Peak-normalise and add a tiny fade at both ends so nothing clicks. Loops
## pass `fade_time = 0` — a fade there would dip at every loop point.
static func finish(samples: PackedFloat32Array, peak: float = 0.85, fade_time: float = 0.005) -> PackedFloat32Array:
	var loudest := 0.0
	for s in samples:
		loudest = maxf(loudest, absf(s))
	var gain := peak / (loudest if loudest > 0.0 else 1.0)
	var n := samples.size()
	var fade := sample_count(fade_time)
	for i in n:
		var v := samples[i] * gain
		if fade > 0:
			if i < fade:
				v *= float(i) / fade
			if i >= n - fade:
				v *= float(n - 1 - i) / fade
		samples[i] = v
	return samples

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
	var lowpass := LowPass.new()
	var body := Formant.new()
	var noise_filter := LowPass.new()
	var jitter_filter := LowPass.new()
	var knock_filter := LowPass.new()
	var harmonics: int = options.get("harmonics", 20)
	var rolloff: float = options.get("rolloff", 1.2)
	var sub: float = options.get("sub", 0.0)
	var noise_level: float = options.get("noise", 0.0)
	var noise_cutoff: float = options.get("noise_cutoff", 2000.0)
	var jitter: float = options.get("jitter", 0.0)
	var jitter_rate: float = options.get("jitter_rate", 80.0)
	var knock: float = options.get("knock", 0.0)
	var knock_rate: float = options.get("knock_rate", 18.0)
	var drive: float = options.get("drive", 0.0)
	var resonance: Array = options.get("resonance", [])
	var jitter_gain := lowpass_noise_gain(jitter_rate)
	var knock_gain := lowpass_noise_gain(knock_rate)
	if not resonance.is_empty():
		body.tune(resonance[0], resonance[1])
	noise_filter.tune(noise_cutoff)
	jitter_filter.tune(jitter_rate)
	knock_filter.tune(knock_rate)

	var out := PackedFloat32Array()
	out.resize(sample_count(duration))
	var phase := 0.0
	var sub_phase := 0.0
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var frequency := curve(options.freq, t)
		if jitter > 0.0:
			frequency *= 1.0 + jitter * jitter_filter.step(rng.randf_range(-1.0, 1.0)) * jitter_gain
		if knock > 0.0:
			frequency *= 1.0 + knock * knock_filter.step(rng.randf_range(-1.0, 1.0)) * knock_gain
		frequency = maxf(frequency, 8.0)
		phase += frequency / SAMPLE_RATE
		var source := buzz(phase, frequency, harmonics, rolloff)
		if sub > 0.0:
			sub_phase += frequency * 0.5 / SAMPLE_RATE
			source += sub * sin(TAU * sub_phase)
		if noise_level > 0.0:
			source += noise_filter.step(rng.randf_range(-1.0, 1.0)) * noise_level
		source = softclip(source, drive * 4.0)
		source = lowpass.process(source, curve(options.cutoff, t))
		if not resonance.is_empty():
			source += body.step(source) * resonance[2]
		out[i] = source * curve(options.amp, t)
	return finish(out)

## One or more sine tones with their own pitch curves (horns, chimes, beeps).
## Options: amp (curve), square (0..1 squareness), tremolo ([rate, depth]).
static func tones(duration: float, frequency_curves: Array, options: Dictionary) -> PackedFloat32Array:
	var squareness: float = options.get("square", 0.0)
	var tremolo: Array = options.get("tremolo", [])
	var phases := PackedFloat64Array()
	phases.resize(frequency_curves.size())
	var out := PackedFloat32Array()
	out.resize(sample_count(duration))
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var sum := 0.0
		for c in frequency_curves.size():
			phases[c] += curve(frequency_curves[c], t) / SAMPLE_RATE
			sum += softclip(sin(TAU * phases[c]), squareness * 6.0)
		var amplitude := curve(options.amp, t)
		if not tremolo.is_empty():
			var wobble := 0.5 + 0.5 * sin(TAU * tremolo[0] * t)
			amplitude *= 1.0 - tremolo[1] + tremolo[1] * wobble
		out[i] = sum / frequency_curves.size() * amplitude
	return finish(out, options.get("peak", 0.85), options.get("fade", 0.005))

## Band-passed noise with swept centre and Q (tyre squeal, skids, wind, hiss).
## Options: freq, q, amp (curves), highpass (Hz), lowpass (Hz).
static func noise_sweep(duration: float, options: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var band := Formant.new()
	var highpass := HighPass.new()
	var lowpass := LowPass.new()
	var highpass_cutoff: float = options.get("highpass", 0.0)
	var lowpass_cutoff: float = options.get("lowpass", 0.0)
	highpass.tune(maxf(highpass_cutoff, 1.0))
	lowpass.tune(maxf(lowpass_cutoff, 1.0))
	var out := PackedFloat32Array()
	out.resize(sample_count(duration))
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var n := rng.randf_range(-1.0, 1.0)
		if highpass_cutoff > 0.0:
			n = highpass.step(n)
		if lowpass_cutoff > 0.0:
			n = lowpass.step(n)
		out[i] = band.process(n, curve(options.freq, t), curve(options.q, t)) * curve(options.amp, t)
	return finish(out, options.get("peak", 0.85), options.get("fade", 0.005))

## Short noise burst through a low-pass with a fast attack and exponential-ish
## decay — the building block for thumps, clunks and slams.
static func thump(duration: float, cutoff: float, attack: float, decay: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var lowpass := LowPass.new()
	lowpass.tune(cutoff)
	var out := PackedFloat32Array()
	out.resize(sample_count(duration))
	for i in out.size():
		var t := float(i) / SAMPLE_RATE
		var envelope := t / attack if t < attack else maxf(0.0, 1.0 - (t - attack) / decay)
		out[i] = lowpass.step(rng.randf_range(-1.0, 1.0)) * envelope * envelope
	return out

static func to_stream(samples: PackedFloat32Array, looping: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
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
