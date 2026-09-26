class_name SoundLibrary
extends RefCounted
## Every one-shot and looping sound effect in the game, each built from code
## with Synth. Sounds are addressed by name (`Sfx.play(&"backfire")`); the Sfx
## autoload renders each one once and caches the stream.
##
## To add a sound: add its name to NAMES (and LOOPING if it loops seamlessly),
## add a `match` arm in `render()`, and write its builder below. Loops must
## start and end on the same level with `fade = 0`, or they click every cycle.

const NAMES: Array[StringName] = [
	&"ui_click",
	&"ui_hover",
	&"ignition_click",
	&"engine_stall",
	&"backfire",
	&"horn_loop",
	&"tire_screech_loop",
	&"bump",
	&"collision",
	&"door_close",
	&"scrap_pickup",
	&"part_pickup",
	&"cash_register",
	&"denied",
	&"trash_rummage",
	&"wrench_clunk",
	&"crane_clang",
	&"crane_miss",
	&"rain_loop",
]

const LOOPING: Array[StringName] = [
	&"horn_loop",
	&"tire_screech_loop",
	&"rain_loop",
]

const CAR_SOUNDS: Array[StringName] = [
	&"ignition_click",
	&"engine_stall",
	&"backfire",
	&"horn_loop",
	&"tire_screech_loop",
	&"bump",
	&"collision",
]

const UI_SOUNDS: Array[StringName] = [
	&"ui_click",
	&"ui_hover",
]

const AMBIENT_SOUNDS: Array[StringName] = [
	&"rain_loop",
]

## The AudioSettings bus a sound plays on, so each volume slider covers it.
static func bus_for(sound_name: StringName) -> StringName:
	if CAR_SOUNDS.has(sound_name):
		return AudioSettings.CARS
	if UI_SOUNDS.has(sound_name):
		return AudioSettings.UI
	if AMBIENT_SOUNDS.has(sound_name):
		return AudioSettings.AMBIENCE
	return AudioSettings.SFX

static func build_stream(sound_name: StringName) -> AudioStreamWAV:
	return Synth.to_stream(render(sound_name), LOOPING.has(sound_name))

static func render(sound_name: StringName) -> PackedFloat32Array:
	# Seeded per sound so the noise, and therefore the sound, is identical on
	# every launch.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound_name)
	match sound_name:
		&"ui_click": return _ui_click(rng)
		&"ui_hover": return _ui_hover()
		&"ignition_click": return _ignition_click(rng)
		&"engine_stall": return _engine_stall(rng)
		&"backfire": return _backfire(rng)
		&"horn_loop": return _horn_loop()
		&"tire_screech_loop": return _tire_screech_loop(rng)
		&"bump": return _bump(rng)
		&"collision": return _collision(rng)
		&"door_close": return _door_close(rng)
		&"scrap_pickup": return _scrap_pickup()
		&"part_pickup": return _part_pickup()
		&"cash_register": return _cash_register(rng)
		&"denied": return _denied()
		&"trash_rummage": return _trash_rummage(rng)
		&"wrench_clunk": return _wrench_clunk(rng)
		&"crane_clang": return _crane_clang(rng)
		&"crane_miss": return _crane_miss(rng)
		&"rain_loop": return _rain_loop(rng)
	push_error("SoundLibrary: unknown sound '%s'" % sound_name)
	return Synth.silence(0.05)

# --- Engine -------------------------------------------------------------------

## Key turning in the ignition: a light click, then the heavier clack of the
## starter solenoid. No motor here — the running engine itself fades in after
## (see EngineSound.start_up) so the start always matches the fitted engine.
static func _ignition_click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var key := _metal_ring(0.04, 3200.0, 8.0, 0.008, rng)
	var solenoid := Synth.mix_into(Synth.thump(0.08, 900.0, 0.002, 0.04, rng),
			_metal_ring(0.08, 1600.0, 10.0, 0.015, rng), 0.0, 0.6)
	return Synth.finish(Synth.mix_into(key, solenoid, 0.12, 1.0), 0.7)

static func _engine_stall(rng: RandomNumberGenerator) -> PackedFloat32Array:
	return Synth.engine(1.6, {
		freq = [[0.0, 100.0], [0.3, 70.0], [0.5, 90.0], [0.7, 50.0],
				[0.9, 75.0], [1.1, 35.0], [1.6, 15.0]],
		cutoff = [[0.0, 900.0], [1.6, 500.0]],
		harmonics = 18, rolloff = 1.3, sub = 0.4, drive = 0.3,
		noise = 0.35, noise_cutoff = 1200.0,
		jitter = 0.06, jitter_rate = 40.0,
		amp = [[0.0, 0.0], [0.06, 0.9], [0.7, 0.7], [1.1, 0.5], [1.6, 0.0]],
	}, rng)

static func _backfire(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var lowpass := Synth.LowPass.new()
	lowpass.tune(300.0)
	var out := Synth.silence(0.35)
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		var crack := rng.randf_range(-1.0, 1.0) if t < 0.01 else 0.0
		var boom := lowpass.step(rng.randf_range(-1.0, 1.0)) * pow(maxf(0.0, 1.0 - t / 0.3), 2.0)
		out[i] = crack * 1.5 + boom
	return Synth.finish(out)

# --- Horn & tyres -------------------------------------------------------------

## Steady two-tone horn, exactly 1 s so both 330 Hz and 415 Hz finish whole
## cycles and the loop point is seamless. Attack/release come from the player's
## volume fade (see SustainedSound), not from the samples.
static func _horn_loop() -> PackedFloat32Array:
	return Synth.tones(1.0, [[[0.0, 330.0]], [[0.0, 415.0]]], {
		square = 0.4,
		amp = [[0.0, 1.0]],
		fade = 0.0,
	})

## Pitched rubber squeal with a wandering pitch, a second tyre chirping above
## it, stick-slip chatter and a little scrub noise underneath. Every wobble is a
## whole number of Hz over the 1 s loop so the pitch lines up at the seam.
static func _tire_screech_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var duration := 1.0
	var scrub := Synth.noise_sweep(duration, {
		freq = [[0.0, 1800.0]],
		q = [[0.0, 1.5]],
		highpass = 300.0,
		amp = [[0.0, 1.0]],
		fade = 0.0,
	}, rng)
	var out := Synth.silence(duration)
	var squeal_phase := 0.0
	var chirp_phase := 0.0
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		var wobble := 70.0 * sin(TAU * 2.0 * t) + 45.0 * sin(TAU * 6.0 * t) + 25.0 * sin(TAU * 17.0 * t)
		squeal_phase += (1150.0 + wobble) / Synth.SAMPLE_RATE
		chirp_phase += (1730.0 - wobble * 1.4) / Synth.SAMPLE_RATE
		var squeal := sin(TAU * squeal_phase) + 0.4 * sin(2.0 * TAU * squeal_phase) + 0.2 * sin(3.0 * TAU * squeal_phase)
		var chirp := sin(TAU * chirp_phase) * (0.5 + 0.5 * sin(TAU * 3.0 * t))
		var chatter := 0.7 + 0.3 * sin(TAU * 23.0 * t)
		out[i] = Synth.softclip((0.7 * squeal + 0.3 * chirp) * chatter, 1.5) + 0.35 * scrub[i]
	return Synth.finish(out, 0.85, 0.0)

# --- Impacts ------------------------------------------------------------------

## Light knock — the overworld car nudging a wall, a race car landing hard.
static func _bump(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.25, 220.0, 0.006, 0.16, rng)
	var ring := _metal_ring(0.2, 700.0, 10.0, 0.12, rng)
	return Synth.finish(Synth.mix_into(out, ring, 0.0, 0.25))

static func _collision(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var lowpass := Synth.LowPass.new()
	lowpass.tune(180.0)
	var clang := Synth.Formant.new()
	clang.tune(1200.0, 8.0)
	var out := Synth.silence(0.8)
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		var envelope := t / 0.01 if t < 0.01 else pow(maxf(0.0, 1.0 - (t - 0.01) / 0.6), 1.5)
		var crunch := rng.randf_range(-1.0, 1.0) * envelope
		var ring := clang.step(rng.randf_range(-1.0, 1.0)) * maxf(0.0, 1.0 - t / 0.5)
		var boom := lowpass.step(rng.randf_range(-1.0, 1.0)) * envelope
		out[i] = crunch * 0.8 + ring * 0.5 + boom * 0.9
	return Synth.finish(out)

static func _door_close(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.3, 250.0, 0.008, 0.18, rng)
	for i in Synth.sample_count(0.004):
		out[i] += rng.randf_range(-1.0, 1.0) * 0.4 * (1.0 - float(i) / Synth.sample_count(0.004))
	return Synth.finish(out)

## Band-passed noise ringing at `frequency` and dying off over `decay` —
## a struck piece of sheet metal.
static func _metal_ring(duration: float, frequency: float, q: float, decay: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var band := Synth.Formant.new()
	band.tune(frequency, q)
	var out := Synth.silence(duration)
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		out[i] = band.step(rng.randf_range(-1.0, 1.0)) * exp(-t / decay)
	return out

# --- Pickups & money ----------------------------------------------------------

static func _ui_click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var lowpass := Synth.LowPass.new()
	lowpass.tune(3000.0)
	var out := Synth.silence(0.05)
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		var envelope := t / 0.003 if t < 0.003 else maxf(0.0, 1.0 - (t - 0.003) / 0.03)
		out[i] = lowpass.step(rng.randf_range(-1.0, 1.0)) * envelope \
				+ sin(TAU * 1400.0 * t) * envelope * 0.3
	return Synth.finish(out, 0.6)

## Tiny dull tick as the cursor slides onto a button — a fingernail on tin.
static func _ui_hover() -> PackedFloat32Array:
	return Synth.tones(0.035, [[[0.0, 700.0], [0.035, 560.0]]], {
		square = 0.15,
		amp = [[0.0, 0.0], [0.003, 1.0], [0.035, 0.0]],
		peak = 0.5,
	})

## Quick upward blip — a bolt dropping into the scrap bucket.
static func _scrap_pickup() -> PackedFloat32Array:
	return Synth.tones(0.1, [[[0.0, 900.0], [0.1, 1400.0]]], {
		square = 0.25,
		amp = [[0.0, 0.0], [0.005, 1.0], [0.06, 0.6], [0.1, 0.0]],
		peak = 0.6,
	})

## Three-note rising arpeggio — rarer and bigger than a scrap blip.
static func _part_pickup() -> PackedFloat32Array:
	var note := func(frequency: float) -> PackedFloat32Array:
		return Synth.tones(0.1, [[[0.0, frequency]], [[0.0, frequency * 2.0]]], {
			square = 0.2,
			amp = [[0.0, 0.0], [0.005, 1.0], [0.07, 0.7], [0.1, 0.0]],
		})
	return Synth.concat([note.call(660.0), note.call(880.0), note.call(1320.0)])

## "Ka-ching": drawer clunk, then a bell pair ringing out.
static func _cash_register(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var drawer := Synth.thump(0.12, 400.0, 0.004, 0.08, rng)
	var bell := Synth.tones(0.6, [[[0.0, 1318.0]], [[0.0, 1760.0]]], {
		amp = [[0.0, 0.0], [0.005, 1.0], [0.1, 0.6], [0.6, 0.0]],
		tremolo = [18.0, 0.3],
	})
	var out := Synth.mix_into(Synth.finish(drawer), bell, 0.07, 0.8)
	return Synth.finish(out)

## Low double buzz for "can't do that" (no money, nothing to sell).
static func _denied() -> PackedFloat32Array:
	return Synth.tones(0.3, [[[0.0, 180.0]], [[0.0, 190.0]]], {
		square = 0.6,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.11, 1.0], [0.12, 0.0],
				[0.16, 0.0], [0.17, 1.0], [0.28, 1.0], [0.3, 0.0]],
		peak = 0.55,
	})

# --- Junk handling ------------------------------------------------------------

## Lid bang, then junk rattling around inside the bin.
static func _trash_rummage(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.mix_into(Synth.thump(0.2, 300.0, 0.004, 0.12, rng),
			_metal_ring(0.35, 850.0, 14.0, 0.1, rng), 0.0, 0.5)
	for hit in 5:
		var offset := 0.12 + hit * 0.07 + rng.randf_range(0.0, 0.03)
		var ring := _metal_ring(0.12, rng.randf_range(1200.0, 2600.0), 12.0, 0.03, rng)
		Synth.mix_into(out, ring, offset, rng.randf_range(0.25, 0.5))
	return Synth.finish(out)

## Wrench tightening a part onto the car: a dull clunk with a short metal ring.
static func _wrench_clunk(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.3, 320.0, 0.004, 0.15, rng)
	Synth.mix_into(out, _metal_ring(0.3, 1400.0, 20.0, 0.08, rng), 0.0, 0.4)
	Synth.mix_into(out, _metal_ring(0.25, 2100.0, 25.0, 0.05, rng), 0.0, 0.25)
	return Synth.finish(out)

## Big steel jaws biting into the heap.
static func _crane_clang(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.7, 200.0, 0.005, 0.35, rng)
	Synth.mix_into(out, _metal_ring(0.7, 640.0, 30.0, 0.25, rng), 0.0, 0.5)
	Synth.mix_into(out, _metal_ring(0.5, 1020.0, 30.0, 0.15, rng), 0.0, 0.3)
	return Synth.finish(out)

## Jaws snapping shut on nothing.
static func _crane_miss(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _metal_ring(0.3, 900.0, 18.0, 0.07, rng)
	Synth.mix_into(out, Synth.thump(0.15, 500.0, 0.003, 0.06, rng), 0.0, 0.6)
	return Synth.finish(out, 0.6)

# --- Ambience -----------------------------------------------------------------

## Steady hiss of rain on tarmac. Level is set by the player from
## Weather.rain_intensity, so the samples themselves stay flat.
static func _rain_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	return Synth.noise_sweep(2.0, {
		freq = [[0.0, 3000.0]],
		q = [[0.0, 0.7]],
		highpass = 400.0,
		amp = [[0.0, 1.0]],
		fade = 0.0,
		peak = 0.7,
	}, rng)
