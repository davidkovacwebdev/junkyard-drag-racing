class_name EngineSound
extends AudioStreamPlayer2D
## A running engine, synthesized live from an EngineSoundProfile — same voice as
## Synth.engine(), but fed every frame so pitch and tone follow the car instead
## of being baked in. Whoever owns the car sets `rpm` (0 idle .. 1 flat out)
## and `throttle` (0..1); this does the rest.
##
## The piston buzz is read from a precomputed one-cycle wavetable rather than
## summing sines per sample, which keeps a live engine cheap enough to run one
## per car in a race.

const WAVETABLE_SIZE := 2048
const BUFFER_SECONDS := 0.08
## How fast rpm/throttle changes are allowed to land. Real engines don't jump.
const RPM_RESPONSE := 6.0
const THROTTLE_RESPONSE := 10.0
const START_BLIP_RPM := 0.35

@export var profile: EngineSoundProfile

var rpm: float = 0.0
var throttle: float = 0.0

## 0..1 fade on top of everything, for starting up or cutting out.
var master_level: float = 1.0

static var _wavetables: Dictionary = {}

var _start_blip: float = 0.0

var _playback: AudioStreamGeneratorPlayback
var _wavetable: PackedFloat32Array
var _rng := RandomNumberGenerator.new()
var _smoothed_rpm: float = 0.0
var _smoothed_throttle: float = 0.0
var _phase: float = 0.0
var _sub_phase: float = 0.0
var _whine_phase: float = 0.0
var _chuff_phase: float = 0.0
var _last_frequency: float = 0.0
var _last_amplitude: float = 0.0
var _lowpass_y: float = 0.0
var _noise_y: float = 0.0
var _jitter_y: float = 0.0
var _knock_y: float = 0.0
var _body := Synth.Formant.new()
var _jitter_gain: float = 0.0
var _knock_gain: float = 0.0
var _gust_y: float = 0.0
var _gust_gain: float = 0.0

func _ready() -> void:
	bus = AudioSettings.CARS
	if profile == null:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = Synth.SAMPLE_RATE
	generator.buffer_length = BUFFER_SECONDS
	stream = generator
	_wavetable = _wavetable_for(profile)
	_jitter_gain = Synth.lowpass_noise_gain(profile.jitter_rate)
	_knock_gain = Synth.lowpass_noise_gain(profile.knock_rate)
	_gust_gain = Synth.lowpass_noise_gain(profile.gust_rate)
	if profile.resonance_frequency > 0.0:
		_body.tune(profile.resonance_frequency, profile.resonance_q)
	_last_frequency = profile.idle_frequency
	play()
	_playback = get_stream_playback()

## Bring the engine to life after `delay` (the ignition click): it fades up
## from silence with a short rev blip as it catches, then settles to whatever
## `rpm` its owner is asking for. The catch comes from this same voice, so the
## start always matches the engine that's fitted.
func start_up(delay: float = 0.0) -> void:
	master_level = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: _start_blip = START_BLIP_RPM)
	tween.tween_property(self, "master_level", 1.0, 0.25)
	tween.tween_property(self, "_start_blip", 0.0, 0.8)

func _process(delta: float) -> void:
	if _playback == null:
		return
	_smoothed_rpm = lerpf(_smoothed_rpm, clampf(rpm + _start_blip, 0.0, 1.2), 1.0 - exp(-RPM_RESPONSE * delta))
	_smoothed_throttle = lerpf(_smoothed_throttle, clampf(throttle, 0.0, 1.0), 1.0 - exp(-THROTTLE_RESPONSE * delta))
	_fill_buffer()

func _fill_buffer() -> void:
	var frames := _playback.get_frames_available()
	if frames > 0:
		_playback.push_buffer(synthesize(frames))

## The next `frames` samples at the current rpm/throttle. The hot loop: filters
## and profile fields are pulled into locals because GDScript method calls and
## property reads per sample are what cost the most here; the filter state is
## written back once at the end.
func synthesize(frames: int) -> PackedVector2Array:
	var load_amount := _smoothed_throttle * profile.throttle_boost
	var frequency := lerpf(profile.idle_frequency, profile.max_frequency, _smoothed_rpm)
	var amplitude := lerpf(profile.idle_volume, profile.max_volume, _smoothed_rpm) * (1.0 + load_amount) * master_level
	var cutoff := lerpf(profile.cutoff_idle, profile.cutoff_max, clampf(_smoothed_rpm + load_amount, 0.0, 1.2))

	var lowpass_a := Synth.one_pole_coefficient(cutoff)
	var noise_a := Synth.one_pole_coefficient(profile.noise_cutoff)
	var jitter_a := Synth.one_pole_coefficient(profile.jitter_rate)
	var knock_a := Synth.one_pole_coefficient(profile.knock_rate)
	var jitter_depth := profile.jitter * _jitter_gain
	var knock_depth := profile.knock * _knock_gain
	var buzz_level := profile.buzz_level
	var sub_level := profile.sub_level
	var noise_level := profile.noise_level * 3.0
	var drive := profile.drive * 4.0
	var has_resonance := profile.resonance_frequency > 0.0
	var body_b0 := _body.b0
	var body_a1 := _body.a1
	var body_a2 := _body.a2
	var body_x1 := _body.x1
	var body_x2 := _body.x2
	var body_y1 := _body.y1
	var body_y2 := _body.y2
	var resonance_gain := profile.resonance_gain
	var whine_level := profile.whine_level
	var whine_ratio := profile.whine_ratio
	var chuff_level := profile.chuff_level
	var chuff_ratio := profile.chuff_ratio
	var chuff_sharpness := profile.chuff_sharpness
	var gust_depth := profile.gust_level * _gust_gain
	var gust_a := Synth.one_pole_coefficient(profile.gust_rate)
	var inverse_rate := 1.0 / Synth.SAMPLE_RATE
	var table := _wavetable
	var table_size := float(WAVETABLE_SIZE)
	var table_mask := WAVETABLE_SIZE - 1

	var lowpass_y := _lowpass_y
	var noise_y := _noise_y
	var jitter_y := _jitter_y
	var knock_y := _knock_y
	var phase := _phase
	var sub_phase := _sub_phase
	var whine_phase := _whine_phase
	var chuff_phase := _chuff_phase
	var gust_y := _gust_y

	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i in frames:
		# Ramp pitch and level across the chunk instead of stepping them once a
		# frame, which would zipper audibly.
		var k := float(i + 1) / frames
		var noise := _rng.randf() * 2.0 - 1.0
		jitter_y += jitter_a * (noise - jitter_y)
		knock_y += knock_a * (noise - knock_y)
		var f := lerpf(_last_frequency, frequency, k) * (1.0 + jitter_depth * jitter_y + knock_depth * knock_y)
		f = maxf(f, 0.5)

		phase += f * inverse_rate
		if phase >= 1.0:
			phase -= 1.0
		var table_position := phase * table_size
		var index := int(table_position)
		var fraction := table_position - index
		var a := table[index]
		var source := (a + (table[(index + 1) & table_mask] - a) * fraction) * buzz_level
		if sub_level > 0.0:
			sub_phase += f * 0.5 * inverse_rate
			if sub_phase >= 1.0:
				sub_phase -= 1.0
			source += sub_level * sin(TAU * sub_phase)
		if noise_level > 0.0:
			noise_y += noise_a * (noise - noise_y)
			source += noise_y * noise_level
		if drive > 0.0:
			source = (1.0 + drive) * source / (1.0 + drive * absf(source))
		lowpass_y += lowpass_a * (source - lowpass_y)
		source = lowpass_y
		if has_resonance:
			var resonant := body_b0 * (source - body_x2) - body_a1 * body_y1 - body_a2 * body_y2
			body_x2 = body_x1
			body_x1 = source
			body_y2 = body_y1
			body_y1 = resonant
			source += resonant * resonance_gain
		if whine_level > 0.0:
			whine_phase += f * whine_ratio * inverse_rate
			whine_phase -= floorf(whine_phase)
			source += sin(TAU * whine_phase) * whine_level

		var level := lerpf(_last_amplitude, amplitude, k)
		if chuff_level > 0.0:
			chuff_phase += f * chuff_ratio * inverse_rate
			chuff_phase -= floorf(chuff_phase)
			var pulse := pow(0.5 + 0.5 * sin(TAU * chuff_phase), chuff_sharpness)
			level *= 1.0 - chuff_level + chuff_level * pulse
		if gust_depth > 0.0:
			gust_y += gust_a * (noise - gust_y)
			level *= clampf(1.0 + gust_depth * gust_y, 0.15, 2.0)
		var sample := tanh(source * level) * 0.8
		buffer[i] = Vector2(sample, sample)

	_lowpass_y = lowpass_y
	_body.x1 = body_x1
	_body.x2 = body_x2
	_body.y1 = body_y1
	_body.y2 = body_y2
	_noise_y = noise_y
	_jitter_y = jitter_y
	_knock_y = knock_y
	_phase = phase
	_sub_phase = sub_phase
	_whine_phase = whine_phase
	_chuff_phase = chuff_phase
	_gust_y = gust_y
	_last_frequency = frequency
	_last_amplitude = amplitude
	return buffer

## One normalised cycle of the band-limited buzz, shared by every engine with
## the same harmonic recipe. Harmonics are capped so the top one stays under
## Nyquist even at the profile's max firing frequency.
static func _wavetable_for(sound_profile: EngineSoundProfile) -> PackedFloat32Array:
	var harmonics := mini(sound_profile.harmonics,
			int((Synth.SAMPLE_RATE / 2.0 - 200.0) / (sound_profile.max_frequency * 1.2)))
	harmonics = maxi(harmonics, 1)
	var key := "%d:%.3f" % [harmonics, sound_profile.rolloff]
	if _wavetables.has(key):
		return _wavetables[key]
	var table := PackedFloat32Array()
	table.resize(WAVETABLE_SIZE)
	var loudest := 0.0
	for i in WAVETABLE_SIZE:
		var phase := float(i) / WAVETABLE_SIZE
		var sum := 0.0
		for h in range(1, harmonics + 1):
			sum += sin(TAU * h * phase) / pow(h, sound_profile.rolloff)
		table[i] = sum
		loudest = maxf(loudest, absf(sum))
	for i in WAVETABLE_SIZE:
		table[i] /= loudest
	_wavetables[key] = table
	return table
