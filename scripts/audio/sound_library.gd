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
	&"dialog_open",
	&"cutscene_whoosh",
	&"outfit_swap",
	&"journal_flip",
	&"quest_added",
	&"shop_bell",
	&"quest_complete",
	&"beer_sip",
	&"grandpa_twitch",
	&"grandpa_sob",
	&"grandpa_hiccup",
	&"wink_ting",
	&"gate_rattle",
	&"trunk_open",
	&"trunk_close",
	&"ignition_click",
	&"headlight_click",
	&"engine_stall",
	&"backfire",
	&"race_stalled",
	&"results_fanfare",
	&"horn_loop",
	&"tire_screech_loop",
	&"bump",
	&"collision",
	&"mattress_squish",
	&"sign_wobble",
	&"pogo_boing",
	&"prosthetic_clunk",
	&"flat_tire_flop",
	&"giant_tire_boom",
	&"robot_stomp",
	&"fuselage_bong",
	&"bone_clatter",
	&"track_clank",
	&"radiator_clang",
	&"bicycle_rattle",
	&"tractor_thud",
	&"hamster_squeak",
	&"tv_thunk",
	&"paddle_splash",
	&"rock_clack",
	&"metal_scrape",
	&"spike_pop",
	&"gravel_crunch",
	&"door_close",
	&"scrap_pickup",
	&"part_pickup",
	&"cash_register",
	&"denied",
	&"trash_rummage",
	&"wrench_clunk",
	&"crane_clang",
	&"crane_miss",
	&"crane_shove",
	&"rooster_crow",
	&"horse_neigh",
	&"forge_hammer",
	&"forge_quench",
	&"crucible_drop",
	&"shark_splash",
	&"trash_splash",
	&"truck_honk",
	&"rain_loop",
	&"furnace_loop",
	&"gull_cry",
	&"foghorn",
	&"crow_caw",
	&"cricket_chirp",
	&"pumpjack_creak",
]

const LOOPING: Array[StringName] = [
	&"horn_loop",
	&"tire_screech_loop",
	&"rain_loop",
	&"furnace_loop",
]

const CAR_SOUNDS: Array[StringName] = [
	&"ignition_click",
	&"headlight_click",
	&"engine_stall",
	&"backfire",
	&"horn_loop",
	&"tire_screech_loop",
	&"bump",
	&"collision",
	&"mattress_squish",
	&"sign_wobble",
	&"pogo_boing",
	&"prosthetic_clunk",
	&"flat_tire_flop",
	&"giant_tire_boom",
	&"robot_stomp",
	&"fuselage_bong",
	&"bone_clatter",
	&"track_clank",
	&"radiator_clang",
	&"bicycle_rattle",
	&"tractor_thud",
	&"hamster_squeak",
	&"tv_thunk",
	&"paddle_splash",
	&"rock_clack",
	&"metal_scrape",
	&"spike_pop",
	&"gravel_crunch",
]

const UI_SOUNDS: Array[StringName] = [
	&"ui_click",
	&"ui_hover",
	&"dialog_open",
	&"cutscene_whoosh",
	&"outfit_swap",
	&"journal_flip",
	&"quest_added",
	&"quest_complete",
	&"trunk_open",
	&"trunk_close",
]

const AMBIENT_SOUNDS: Array[StringName] = [
	&"shark_splash",
	&"trash_splash",
	&"rain_loop",
	&"furnace_loop",
	&"gull_cry",
	&"foghorn",
	&"crow_caw",
	&"cricket_chirp",
	&"pumpjack_creak",
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
		&"dialog_open": return _dialog_open(rng)
		&"cutscene_whoosh": return _cutscene_whoosh(rng)
		&"outfit_swap": return _outfit_swap(rng)
		&"journal_flip": return _journal_flip(rng)
		&"quest_added": return _quest_added(rng)
		&"shop_bell": return _shop_bell()
		&"quest_complete": return _quest_complete()
		&"beer_sip": return _beer_sip(rng)
		&"grandpa_twitch": return _grandpa_twitch(rng)
		&"grandpa_sob": return _grandpa_sob(rng)
		&"grandpa_hiccup": return _grandpa_hiccup(rng)
		&"wink_ting": return _wink_ting()
		&"gate_rattle": return _gate_rattle(rng)
		&"trunk_open": return _trunk_open(rng)
		&"trunk_close": return _trunk_close(rng)
		&"ignition_click": return _ignition_click(rng)
		&"headlight_click": return _headlight_click(rng)
		&"engine_stall": return _engine_stall(rng)
		&"backfire": return _backfire(rng)
		&"race_stalled": return _race_stalled()
		&"results_fanfare": return _results_fanfare()
		&"horn_loop": return _horn_loop()
		&"truck_honk": return _truck_honk()
		&"tire_screech_loop": return _tire_screech_loop(rng)
		&"bump": return _bump(rng)
		&"collision": return _collision(rng)
		&"mattress_squish": return _mattress_squish(rng)
		&"sign_wobble": return _sign_wobble(rng)
		&"pogo_boing": return _pogo_boing(rng)
		&"prosthetic_clunk": return _prosthetic_clunk(rng)
		&"flat_tire_flop": return _flat_tire_flop(rng)
		&"giant_tire_boom": return _giant_tire_boom(rng)
		&"robot_stomp": return _robot_stomp(rng)
		&"fuselage_bong": return _fuselage_bong(rng)
		&"bone_clatter": return _bone_clatter(rng)
		&"track_clank": return _track_clank(rng)
		&"radiator_clang": return _radiator_clang(rng)
		&"bicycle_rattle": return _bicycle_rattle(rng)
		&"tractor_thud": return _tractor_thud(rng)
		&"hamster_squeak": return _hamster_squeak(rng)
		&"tv_thunk": return _tv_thunk(rng)
		&"paddle_splash": return _paddle_splash(rng)
		&"rock_clack": return _rock_clack(rng)
		&"metal_scrape": return _metal_scrape(rng)
		&"spike_pop": return _spike_pop(rng)
		&"gravel_crunch": return _gravel_crunch(rng)
		&"door_close": return _door_close(rng)
		&"scrap_pickup": return _scrap_pickup()
		&"part_pickup": return _part_pickup()
		&"cash_register": return _cash_register(rng)
		&"denied": return _denied()
		&"trash_rummage": return _trash_rummage(rng)
		&"wrench_clunk": return _wrench_clunk(rng)
		&"crane_clang": return _crane_clang(rng)
		&"crane_miss": return _crane_miss(rng)
		&"crane_shove": return _crane_shove(rng)
		&"rooster_crow": return _rooster_crow()
		&"horse_neigh": return _horse_neigh(rng)
		&"forge_hammer": return _forge_hammer(rng)
		&"forge_quench": return _forge_quench(rng)
		&"shark_splash": return _shark_splash(rng)
		&"trash_splash": return _trash_splash(rng)
		&"crucible_drop": return _crucible_drop(rng)
		&"rain_loop": return _rain_loop(rng)
		&"furnace_loop": return _furnace_loop(rng)
		&"gull_cry": return _gull_cry()
		&"foghorn": return _foghorn(rng)
		&"crow_caw": return _crow_caw(rng)
		&"cricket_chirp": return _cricket_chirp()
		&"pumpjack_creak": return _pumpjack_creak(rng)
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

## Dashboard light switch: a plasticky tick, then the relay under the hood
## clacking in a beat later.
static func _headlight_click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var switch := _metal_ring(0.03, 2600.0, 9.0, 0.006, rng)
	var relay := Synth.mix_into(Synth.thump(0.05, 1400.0, 0.002, 0.025, rng),
			_metal_ring(0.05, 2100.0, 12.0, 0.01, rng), 0.0, 0.5)
	return Synth.finish(Synth.mix_into(switch, relay, 0.06, 0.6), 0.6)

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
## Two grumpy low square-wave honks — the garbage truck telling you off.
static func _truck_honk() -> PackedFloat32Array:
	return Synth.tones(0.56, [[[0.0, 196.0]], [[0.0, 233.0]]], {
		square = 0.55,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.17, 1.0], [0.2, 0.0],
				[0.29, 0.0], [0.3, 1.0], [0.52, 1.0], [0.55, 0.0]],
	})

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

## Soft body landing on something: a padded whump, a puff of fabric and a
## rusty spring boinging around inside.
static func _mattress_squish(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.35, 150.0, 0.02, 0.22, rng)
	var fabric := Synth.noise_sweep(0.18, {
		freq = [[0.0, 700.0], [0.18, 400.0]],
		q = [[0.0, 0.8]],
		amp = [[0.0, 0.0], [0.02, 1.0], [0.18, 0.0]],
	}, rng)
	Synth.mix_into(out, fabric, 0.0, 0.3)
	var spring := Synth.tones(0.5, [[[0.0, 260.0], [0.05, 180.0], [0.1, 235.0], [0.16, 170.0],
			[0.23, 215.0], [0.32, 165.0], [0.5, 150.0]]], {
		square = 0.25,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.2, 0.5], [0.5, 0.0]],
		tremolo = [14.0, 0.4],
	})
	Synth.mix_into(out, spring, 0.02, 0.25)
	return Synth.finish(out)

## Thin sheet-metal road sign smacking the ground: a tinny whack, then the
## sheet warbling like a wobble board.
static func _sign_wobble(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.12, 600.0, 0.002, 0.06, rng)
	Synth.mix_into(out, _metal_ring(0.4, 1900.0, 25.0, 0.1, rng), 0.0, 0.35)
	var warble := Synth.tones(0.45, [[[0.0, 420.0], [0.45, 300.0]], [[0.0, 633.0], [0.45, 470.0]]], {
		square = 0.1,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.45, 0.0]],
		tremolo = [11.0, 0.8],
	})
	Synth.mix_into(out, warble, 0.01, 0.4)
	return Synth.finish(out)

## A pogo stick springing off: a rusty squeak, then a coil spring boinging
## upward and wobbling out.
static func _pogo_boing(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.silence(0.45)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		var wobble := 1.0 + 0.3 * sin(TAU * 23.0 * t) * exp(-t * 6.0)
		phase += 190.0 * (1.0 + 1.6 * t) * wobble / Synth.SAMPLE_RATE
		out[i] = Synth.softclip(sin(TAU * phase), 1.5) * exp(-t * 7.0) * minf(1.0, t / 0.004)
	var squeak := Synth.noise_sweep(0.06, {
		freq = [[0.0, 2600.0], [0.06, 3400.0]],
		q = [[0.0, 12.0]],
		amp = [[0.0, 0.0], [0.01, 1.0], [0.06, 0.0]],
	}, rng)
	Synth.mix_into(out, squeak, 0.0, 0.25)
	Synth.mix_into(out, Synth.thump(0.08, 400.0, 0.002, 0.04, rng), 0.0, 0.4)
	return Synth.finish(out)

## A prosthetic foot stomping down: a hollow plastic knock, the knee hinge
## clacking, and an old sneaker squeaking on the ground.
static func _prosthetic_clunk(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.18, 380.0, 0.002, 0.07, rng)
	Synth.mix_into(out, _metal_ring(0.15, 880.0, 6.0, 0.05, rng), 0.0, 0.5)
	Synth.mix_into(out, _metal_ring(0.08, 3200.0, 30.0, 0.02, rng), 0.012, 0.3)
	var squeak := Synth.tones(0.09, [[[0.0, 1500.0], [0.09, 1900.0]]], {
		square = 0.3,
		amp = [[0.0, 0.0], [0.015, 1.0], [0.09, 0.0]],
		tremolo = [45.0, 0.6],
	})
	Synth.mix_into(out, squeak, 0.03, 0.12)
	return Synth.finish(out)

## A flat tyre slapping down: a dull, floppy rubber whump with the loose
## sidewall flapping after it.
static func _flat_tire_flop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.2, 160.0, 0.003, 0.08, rng)
	var flap := Synth.tones(0.18, [[[0.0, 120.0], [0.18, 80.0]]], {
		square = 0.35,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.18, 0.0]],
		tremolo = [26.0, 0.8],
	})
	Synth.mix_into(out, flap, 0.02, 0.45)
	return Synth.finish(out)

## A monster tyre coming down: a huge, slow rubber boom with a deep wobble
## as the giant sidewall rings out.
static func _giant_tire_boom(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.5, 80.0, 0.006, 0.28, rng)
	var wobble := Synth.tones(0.55, [[[0.0, 62.0], [0.12, 44.0], [0.55, 38.0]]], {
		square = 0.15,
		amp = [[0.0, 0.0], [0.015, 1.0], [0.55, 0.0]],
		tremolo = [9.0, 0.6],
	})
	Synth.mix_into(out, wobble, 0.0, 0.7)
	return Synth.finish(out)

## A robot foot stomping down: a servo whirring up, a heavy steel clank and a
## short hydraulic hiss.
static func _robot_stomp(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.silence(0.4)
	var servo := Synth.tones(0.1, [[[0.0, 700.0], [0.1, 1300.0]]], {
		square = 0.5,
		amp = [[0.0, 0.0], [0.02, 1.0], [0.1, 0.2]],
	})
	Synth.mix_into(out, servo, 0.0, 0.15)
	Synth.mix_into(out, Synth.thump(0.25, 260.0, 0.001, 0.08, rng), 0.09, 1.0)
	Synth.mix_into(out, _metal_ring(0.3, 520.0, 14.0, 0.1, rng), 0.09, 0.5)
	var hiss := Synth.noise_sweep(0.15, {
		freq = [[0.0, 5000.0], [0.15, 3500.0]],
		q = [[0.0, 1.2]],
		amp = [[0.0, 0.0], [0.01, 1.0], [0.15, 0.0]],
		highpass = 2500.0,
	}, rng)
	Synth.mix_into(out, hiss, 0.12, 0.2)
	return Synth.finish(out)

## An old airplane fuselage knocked: a hollow aluminium tube going bong.
static func _fuselage_bong(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.25, 400.0, 0.001, 0.06, rng)
	Synth.mix_into(out, _metal_ring(0.8, 240.0, 30.0, 0.3, rng), 0.0, 0.6)
	Synth.mix_into(out, _metal_ring(0.6, 610.0, 26.0, 0.2, rng), 0.0, 0.3)
	return Synth.finish(out)

## A fossil skeleton knocked: a dry thud and a quick clatter of hollow bones
## knocking into each other, like a xylophone falling down the stairs.
static func _bone_clatter(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.1, 500.0, 0.001, 0.03, rng)
	var knock_time := 0.015
	for i in 5:
		var pitch := rng.randf_range(650.0, 1150.0)
		var knock := Synth.tones(0.07, [[[0.0, pitch], [0.07, pitch * 0.9]]], {
			square = 0.1,
			amp = [[0.0, 0.0], [0.002, 1.0], [0.05, 0.0]],
		})
		Synth.mix_into(out, knock, knock_time, 0.5 - 0.06 * i)
		knock_time += rng.randf_range(0.025, 0.05)
	return Synth.finish(out)

## A tank track hitting something: a heavy steel thunk and the loose links
## rattling after it.
static func _track_clank(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.3, 200.0, 0.002, 0.1, rng)
	Synth.mix_into(out, _metal_ring(0.35, 380.0, 12.0, 0.08, rng), 0.0, 0.5)
	var link_time := 0.04
	for i in 4:
		Synth.mix_into(out, _metal_ring(0.08, rng.randf_range(900.0, 1400.0), 10.0, 0.015, rng), link_time, 0.35)
		link_time += rng.randf_range(0.03, 0.05)
	return Synth.finish(out)

## A wooden paddle blade slapping down: a low hollow shaft-thock, a broad
## noisy splash as the blade digs in, and a few bright droplet flecks
## trailing off the top of the stroke.
static func _paddle_splash(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.14, 200.0, 0.002, 0.06, rng)
	var splash := Synth.noise_sweep(0.24, {
		freq = [[0.0, 1600.0], [0.24, 450.0]],
		q = [[0.0, 1.0]],
		amp = [[0.0, 0.0], [0.02, 1.0], [0.24, 0.0]],
	}, rng)
	Synth.mix_into(out, splash, 0.0, 0.5)
	var droplets := Synth.noise_sweep(0.18, {
		freq = [[0.0, 4000.0], [0.18, 2800.0]],
		q = [[0.0, 3.0]],
		amp = [[0.0, 0.0], [0.04, 1.0], [0.18, 0.0]],
		highpass = 2400.0,
	}, rng)
	Synth.mix_into(out, droplets, 0.04, 0.22)
	return Synth.finish(out)

## A wheel rolling onto a rock: a dry stony knock with a gritty skitter of
## gravel kicked off it.
static func _rock_clack(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.12, 1400.0, 0.001, 0.03, rng)
	Synth.mix_into(out, Synth.thump(0.1, 2600.0, 0.001, 0.02, rng), 0.035, 0.6)
	var gravel := Synth.noise_sweep(0.2, {
		freq = [[0.0, 3200.0], [0.2, 2000.0]],
		q = [[0.0, 2.0]],
		amp = [[0.0, 0.0], [0.01, 1.0], [0.2, 0.0]],
		highpass = 1500.0,
	}, rng)
	Synth.mix_into(out, gravel, 0.02, 0.3)
	return Synth.finish(out)

## A rally car coming down hard after a crest: a low suspension thud and a
## spray of loose gravel skittering away.
static func _gravel_crunch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.16, 220.0, 0.002, 0.07, rng)
	var spray := Synth.noise_sweep(0.4, {
		freq = [[0.0, 2600.0], [0.4, 1300.0]],
		q = [[0.0, 1.6]],
		amp = [[0.0, 0.0], [0.015, 1.0], [0.12, 0.5], [0.4, 0.0]],
		highpass = 900.0,
	}, rng)
	Synth.mix_into(out, spray, 0.01, 0.5)
	Synth.mix_into(out, Synth.thump(0.08, 1800.0, 0.001, 0.02, rng), 0.05, 0.3)
	Synth.mix_into(out, Synth.thump(0.08, 2200.0, 0.001, 0.02, rng), 0.11, 0.2)
	return Synth.finish(out)

## Two race cars trading paint: a bodywork thunk, then a grinding screech of
## metal on metal that trails off as they bounce apart.
static func _metal_scrape(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.2, 300.0, 0.002, 0.09, rng)
	var grind := Synth.noise_sweep(0.45, {
		freq = [[0.0, 2400.0], [0.15, 3400.0], [0.45, 1800.0]],
		q = [[0.0, 9.0]],
		amp = [[0.0, 0.0], [0.02, 1.0], [0.25, 0.6], [0.45, 0.0]],
	}, rng)
	Synth.mix_into(out, grind, 0.01, 0.55)
	Synth.mix_into(out, _metal_ring(0.4, 1150.0, 14.0, 0.2, rng), 0.0, 0.3)
	return Synth.finish(out)

## Tyres landing on a bed of spikes: a tinny clank, a sharp pop, then the air
## hissing out of what's left.
static func _spike_pop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.15, 2500.0, 0.001, 0.04, rng)
	Synth.mix_into(out, _metal_ring(0.35, 1650.0, 16.0, 0.15, rng), 0.0, 0.35)
	var hiss := Synth.noise_sweep(1.1, {
		freq = [[0.0, 4200.0], [1.1, 2600.0]],
		q = [[0.0, 1.2]],
		amp = [[0.0, 0.0], [0.03, 1.0], [0.5, 0.55], [1.1, 0.0]],
		highpass = 1500.0,
	}, rng)
	Synth.mix_into(out, hiss, 0.04, 0.45)
	return Synth.finish(out)

## A cast-iron radiator whacking something: a deep dull clang through all its
## fins, then a hiss of steam from the leaky valve.
static func _radiator_clang(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.3, 180.0, 0.002, 0.15, rng)
	Synth.mix_into(out, _metal_ring(0.7, 310.0, 18.0, 0.3, rng), 0.0, 0.5)
	Synth.mix_into(out, _metal_ring(0.5, 745.0, 22.0, 0.18, rng), 0.0, 0.3)
	var steam := Synth.noise_sweep(0.5, {
		freq = [[0.0, 3500.0], [0.5, 5000.0]],
		q = [[0.0, 1.5]],
		amp = [[0.0, 0.0], [0.08, 1.0], [0.5, 0.0]],
		highpass = 2000.0,
	}, rng)
	Synth.mix_into(out, steam, 0.05, 0.2)
	return Synth.finish(out)

## A rusty bicycle hitting something: a thin frame rattle, the chain slapping,
## and the bell getting knocked into a ding.
static func _bicycle_rattle(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.1, 900.0, 0.001, 0.04, rng)
	for i in 4:
		Synth.mix_into(out, _metal_ring(0.06, rng.randf_range(1400.0, 2600.0), 20.0, 0.02, rng), i * 0.035, 0.35)
	var bell := Synth.tones(0.6, [[[0.0, 2100.0]], [[0.0, 5250.0]]], {
		amp = [[0.0, 0.0], [0.003, 1.0], [0.6, 0.0]],
		tremolo = [7.0, 0.3],
	})
	Synth.mix_into(out, bell, 0.02, 0.25)
	return Synth.finish(out)

## A huge tractor tire landing: a deep rubbery whump that wobbles as the
## sidewall flexes, with a splat of mud.
static func _tractor_thud(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.35, 110.0, 0.004, 0.2, rng)
	var flex := Synth.tones(0.3, [[[0.0, 95.0], [0.08, 70.0], [0.16, 85.0], [0.3, 60.0]]], {
		square = 0.2,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.3, 0.0]],
		tremolo = [18.0, 0.5],
	})
	Synth.mix_into(out, flex, 0.0, 0.5)
	var mud := Synth.noise_sweep(0.12, {
		freq = [[0.0, 900.0], [0.12, 350.0]],
		q = [[0.0, 1.2]],
		amp = [[0.0, 0.0], [0.01, 1.0], [0.12, 0.0]],
	}, rng)
	Synth.mix_into(out, mud, 0.01, 0.25)
	return Synth.finish(out)

## The hamster squeaking in fright over a rattle of wire rungs.
static func _hamster_squeak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.silence(0.3)
	for i in 3:
		Synth.mix_into(out, _metal_ring(0.05, rng.randf_range(2500.0, 3800.0), 25.0, 0.015, rng), i * 0.025, 0.25)
	var squeak := Synth.tones(0.14, [[[0.0, 2300.0], [0.04, 3300.0], [0.14, 2600.0]]], {
		square = 0.15,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.1, 0.8], [0.14, 0.0]],
		tremolo = [35.0, 0.4],
	})
	Synth.mix_into(out, squeak, 0.02, 0.6)
	var second_squeak := Synth.tones(0.1, [[[0.0, 2800.0], [0.1, 3500.0]]], {
		square = 0.15,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.1, 0.0]],
	})
	Synth.mix_into(out, second_squeak, 0.18, 0.45)
	return Synth.finish(out)

## An old CRT TV knocking into something: a hollow plastic thunk, the tube
## rattling, and a burst of static as the picture cuts out.
static func _tv_thunk(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.2, 260.0, 0.002, 0.1, rng)
	Synth.mix_into(out, _metal_ring(0.12, 1250.0, 10.0, 0.04, rng), 0.0, 0.3)
	var static_burst := Synth.noise_sweep(0.22, {
		freq = [[0.0, 5000.0], [0.22, 4000.0]],
		q = [[0.0, 0.7]],
		amp = [[0.0, 0.0], [0.02, 1.0], [0.12, 0.6], [0.22, 0.0]],
		highpass = 1500.0,
	}, rng)
	Synth.mix_into(out, static_burst, 0.03, 0.3)
	var hum := Synth.tones(0.22, [[[0.0, 15734.0 / 256.0]], [[0.0, 120.0]]], {
		square = 0.4,
		amp = [[0.0, 0.0], [0.02, 1.0], [0.22, 0.0]],
	})
	Synth.mix_into(out, hum, 0.03, 0.15)
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

## A cardboard board slapped down on a counter, with a little upward pop so
## it reads as "someone's talking to you" rather than a crash.
static func _dialog_open(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.22, 420.0, 0.003, 0.09, rng)
	Synth.mix_into(out, Synth.tones(0.09, [[[0.0, 330.0], [0.09, 520.0]]], {
		square = 0.3,
		amp = [[0.0, 0.0], [0.005, 1.0], [0.09, 0.0]],
	}), 0.01, 0.35)
	return Synth.finish(out, 0.7)

## The letterbox bars sliding shut: a falling whoosh of air and a soft
## cardboard thud as they land.
static func _cutscene_whoosh(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(0.45, {
		freq = [[0.0, 2200.0], [0.4, 500.0]],
		q = [[0.0, 1.4]],
		amp = [[0.0, 0.0], [0.25, 1.0], [0.4, 0.2], [0.45, 0.0]],
	}, rng)
	Synth.mix_into(out, Synth.thump(0.2, 300.0, 0.004, 0.1, rng), 0.38, 0.9)
	return Synth.finish(out, 0.7)

## A shirt snapped out and thrown on: two quick cloth flaps, the second one
## brighter, like shaking out a jacket.
static func _outfit_swap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var flap := func(freq: float) -> PackedFloat32Array:
		return Synth.noise_sweep(0.07, {
			freq = [[0.0, freq], [0.07, freq * 0.6]],
			q = [[0.0, 1.8]],
			amp = [[0.0, 0.0], [0.008, 1.0], [0.07, 0.0]],
		}, rng)
	var out := Synth.silence(0.16)
	Synth.mix_into(out, flap.call(1300.0), 0.0, 0.7)
	Synth.mix_into(out, flap.call(2100.0), 0.07, 1.0)
	return Synth.finish(out, 0.6)

## A beat-up notebook flipped open: a papery riffle, then a soft cardboard
## slap as the cover lands.
static func _journal_flip(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(0.16, {
		freq = [[0.0, 3200.0], [0.14, 1600.0]],
		q = [[0.0, 1.2]],
		amp = [[0.0, 0.0], [0.02, 0.6], [0.06, 0.25], [0.09, 0.7], [0.16, 0.0]],
	}, rng)
	Synth.mix_into(out, Synth.thump(0.12, 380.0, 0.003, 0.06, rng), 0.12, 0.7)
	return Synth.finish(out, 0.6)

## Something new scribbled in the journal: a pencil scratch and a cheap
## two-note toy-keyboard "ding-dong", rising.
static func _quest_added(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(0.12, {
		freq = [[0.0, 4200.0], [0.12, 2600.0]],
		q = [[0.0, 3.0]],
		amp = [[0.0, 0.0], [0.01, 0.5], [0.05, 0.2], [0.08, 0.5], [0.12, 0.0]],
	}, rng)
	var note := func(frequency: float) -> PackedFloat32Array:
		return Synth.tones(0.22, [[[0.0, frequency]], [[0.0, frequency * 2.0]]], {
			square = 0.3,
			amp = [[0.0, 0.0], [0.005, 1.0], [0.08, 0.5], [0.22, 0.0]],
		})
	var full := Synth.silence(0.5)
	Synth.mix_into(full, out, 0.0, 0.5)
	Synth.mix_into(full, note.call(523.0), 0.1, 0.8)
	Synth.mix_into(full, note.call(784.0), 0.24, 0.8)
	return Synth.finish(full, 0.7)

## The little bell over a shop door: two quick tinny dings as the door knocks
## it, the second softer, ringing out.
static func _shop_bell() -> PackedFloat32Array:
	var ding := func(frequency: float) -> PackedFloat32Array:
		return Synth.tones(0.5, [[[0.0, frequency]], [[0.0, frequency * 2.76]], [[0.0, frequency * 5.4]]], {
			square = 0.05,
			amp = [[0.0, 0.0], [0.003, 1.0], [0.06, 0.45], [0.5, 0.0]],
		})
	var out := Synth.silence(0.65)
	Synth.mix_into(out, ding.call(1320.0), 0.0, 0.8)
	Synth.mix_into(out, ding.call(1250.0), 0.13, 0.5)
	return Synth.finish(out, 0.6)

## A quest ticked off: three cheap toy-keyboard notes climbing, the last
## one held.
static func _quest_complete() -> PackedFloat32Array:
	var note := func(frequency: float, length: float) -> PackedFloat32Array:
		return Synth.tones(length, [[[0.0, frequency]], [[0.0, frequency * 2.0]]], {
			square = 0.3,
			amp = [[0.0, 0.0], [0.005, 1.0], [length * 0.4, 0.55], [length, 0.0]],
		})
	var out := Synth.silence(0.75)
	Synth.mix_into(out, note.call(523.0, 0.14), 0.0, 0.75)
	Synth.mix_into(out, note.call(659.0, 0.14), 0.12, 0.75)
	Synth.mix_into(out, note.call(784.0, 0.45), 0.24, 0.85)
	return Synth.finish(out, 0.7)

## A long wet slurp off a beer bottle, ending in a little glug.
static func _beer_sip(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(0.32, {
		freq = [[0.0, 900.0], [0.25, 1600.0], [0.32, 700.0]],
		q = [[0.0, 4.0]],
		amp = [[0.0, 0.0], [0.04, 0.6], [0.2, 0.8], [0.3, 0.2], [0.32, 0.0]],
	}, rng)
	Synth.mix_into(out, Synth.tones(0.08, [[[0.0, 260.0], [0.08, 180.0]]], {
		amp = [[0.0, 0.0], [0.01, 1.0], [0.08, 0.0]],
	}), 0.3, 0.5)
	return Synth.finish(out, 0.6)

## A fit coming on: a jittery, stuttering buzz, like a shorting wire.
static func _grandpa_twitch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.silence(0.6)
	var t := 0.0
	while t < 0.55:
		var length := rng.randf_range(0.02, 0.05)
		var pitch := rng.randf_range(90.0, 180.0)
		Synth.mix_into(out, Synth.tones(length, [[[0.0, pitch]]], {
			square = 0.8,
			amp = [[0.0, 0.0], [0.003, 1.0], [length, 0.0]],
		}), t, rng.randf_range(0.5, 1.0))
		t += length + rng.randf_range(0.005, 0.03)
	return Synth.finish(out, 0.55)

## A drunk old man blubbering: a wet sniff in, then three quavering wails
## that sag in pitch, each one cracking off short.
static func _grandpa_sob(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.silence(1.3)
	Synth.mix_into(out, Synth.noise_sweep(0.22, {
		freq = [[0.0, 1400.0], [0.22, 2600.0]],
		q = [[0.0, 3.0]],
		amp = [[0.0, 0.0], [0.08, 0.7], [0.2, 0.5], [0.22, 0.0]],
	}, rng), 0.0, 0.5)
	var t := 0.25
	for i in 3:
		var length := rng.randf_range(0.22, 0.3)
		var top := rng.randf_range(300.0, 340.0) - i * 25.0
		Synth.mix_into(out, Synth.tones(length, [[[0.0, top], [length, top * 0.72]]], {
			square = 0.35,
			tremolo = [11.0, 0.6],
			amp = [[0.0, 0.0], [0.02, 1.0], [length * 0.7, 0.7], [length, 0.0]],
		}), t, 0.8 - i * 0.12)
		t += length + rng.randf_range(0.05, 0.1)
	return Synth.finish(out, 0.55)

## A drunk "hic!": a glottal knock and a quick squeaky upward chirp.
static func _grandpa_hiccup(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.05, 900.0, 0.001, 0.02, rng)
	Synth.mix_into(out, Synth.tones(0.09, [[[0.0, 380.0], [0.09, 720.0]]], {
		square = 0.3,
		amp = [[0.0, 0.0], [0.008, 1.0], [0.09, 0.0]],
	}), 0.015, 0.7)
	return Synth.finish(out, 0.55)

## A cartoon wink: one bright little ting off a tin cup.
static func _wink_ting() -> PackedFloat32Array:
	return Synth.tones(0.4, [[[0.0, 1760.0]], [[0.0, 2640.0]]], {
		amp = [[0.0, 0.0], [0.004, 1.0], [0.08, 0.35], [0.4, 0.0]],
		peak = 0.45,
	})

## Bumping out through the junkyard gate: a chain-link fence shivering, a
## few tinny rattles and the hollow clank of the gate post.
static func _gate_rattle(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.silence(0.7)
	Synth.mix_into(out, Synth.thump(0.18, 520.0, 0.002, 0.07, rng), 0.0, 0.8)
	for i in 6:
		var at := 0.03 + i * rng.randf_range(0.06, 0.09)
		Synth.mix_into(out, Synth.noise_sweep(0.05, {
			freq = [[0.0, rng.randf_range(2200.0, 3400.0)]],
			q = [[0.0, 6.0]],
			amp = [[0.0, 0.0], [0.003, 1.0], [0.05, 0.0]],
		}, rng), at, 0.55 * (1.0 - i * 0.12))
	Synth.mix_into(out, Synth.tones(0.3, [[[0.0, 410.0]], [[0.0, 1030.0]]], {
		square = 0.2,
		amp = [[0.0, 0.0], [0.003, 1.0], [0.3, 0.0]],
	}), 0.0, 0.35)
	return Synth.finish(out, 0.6)

## Popping a rusty trunk: the latch clacks, the hinges groan as the lid
## swings up, and it bounces to a stop.
static func _trunk_open(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.silence(0.6)
	Synth.mix_into(out, Synth.thump(0.05, 2400.0, 0.001, 0.02, rng), 0.0, 0.7)
	Synth.mix_into(out, Synth.tones(0.34, [[[0.0, 190.0], [0.3, 320.0]]], {
		square = 0.6,
		amp = [[0.0, 0.0], [0.04, 0.35], [0.28, 0.25], [0.34, 0.0]],
	}), 0.05, 0.5)
	Synth.mix_into(out, Synth.thump(0.16, 260.0, 0.004, 0.08, rng), 0.4, 0.8)
	return Synth.finish(out, 0.65)

## Slamming it shut: a heavy tinny thud with the latch catching in it.
static func _trunk_close(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.3, 320.0, 0.003, 0.12, rng)
	Synth.mix_into(out, Synth.thump(0.05, 2800.0, 0.001, 0.02, rng), 0.03, 0.6)
	return Synth.finish(out, 0.75)

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

## Two detuned tones sliding down together and cutting out — a junkyard
## sad-trombone for "nobody's going anywhere," played when the race gives
## up on itself instead of grinding out the rest of max_duration.
static func _race_stalled() -> PackedFloat32Array:
	return Synth.tones(0.7, [[[0.0, 220.0], [0.7, 80.0]], [[0.0, 165.0], [0.7, 60.0]]], {
		square = 0.45,
		amp = [[0.0, 0.0], [0.04, 0.8], [0.5, 0.55], [0.7, 0.0]],
		peak = 0.55,
	})

## Three-note ascending pluck (junkyard kazoo, not a brass fanfare) for the
## results screen showing a real podium — skipped on a STALLED ending,
## which gets `race_stalled` instead since there's nothing to celebrate.
static func _results_fanfare() -> PackedFloat32Array:
	return Synth.tones(0.6, [[[0.0, 392.0], [0.18, 392.0], [0.2, 523.0], [0.36, 523.0],
			[0.38, 659.0]]], {
		square = 0.35,
		amp = [[0.0, 0.0], [0.02, 0.85], [0.16, 0.7], [0.2, 0.0],
				[0.22, 0.85], [0.34, 0.7], [0.38, 0.0],
				[0.4, 0.9], [0.55, 0.6], [0.6, 0.0]],
		peak = 0.6,
	})

## Low double buzz for "can't do that" (no money, nothing to sell).
static func _denied() -> PackedFloat32Array:
	return Synth.tones(0.3, [[[0.0, 180.0]], [[0.0, 190.0]]], {
		square = 0.6,
		amp = [[0.0, 0.0], [0.01, 1.0], [0.11, 1.0], [0.12, 0.0],
				[0.16, 0.0], [0.17, 1.0], [0.28, 1.0], [0.3, 0.0]],
		peak = 0.55,
	})

## Kazoo-ish "cock-a-doodle-doo" for skipping to morning: three short squawks
## then a long wobbly one that droops at the end.
static func _rooster_crow() -> PackedFloat32Array:
	var squawk := func(duration: float, start: float, peak: float, end: float) -> PackedFloat32Array:
		return Synth.tones(duration, [[[0.0, start], [duration * 0.3, peak], [duration, end]],
				[[0.0, start * 2.01], [duration * 0.3, peak * 2.01], [duration, end * 2.01]]], {
			square = 0.5,
			amp = [[0.0, 0.0], [0.015, 1.0], [duration * 0.8, 0.8], [duration, 0.0]],
			tremolo = [22.0, 0.25],
			peak = 0.6,
		})
	return Synth.concat([
		squawk.call(0.11, 520.0, 700.0, 640.0),
		squawk.call(0.1, 600.0, 760.0, 700.0),
		squawk.call(0.12, 680.0, 900.0, 860.0),
		squawk.call(0.55, 820.0, 1040.0, 560.0),
	])

## A whinny: a nasal cry that climbs, shakes and falls away, then a snort out
## of the nose.
static func _horse_neigh(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var duration := 1.0
	var shape := [[0.0, 620.0], [0.12, 1050.0], [0.35, 980.0], [0.75, 560.0], [duration, 420.0]]
	var vibrato_rate := 13.0
	var pitch: Array = []
	var steps := int(duration * vibrato_rate * 4.0)
	for step in steps + 1:
		var t := duration * step / steps
		var depth := 0.04 + 0.1 * t
		pitch.append([t, Synth.curve(shape, t) * (1.0 + depth * sin(TAU * vibrato_rate * t))])
	var overtone: Array = []
	for point in pitch:
		overtone.append([point[0], point[1] * 2.02])
	var cry := Synth.tones(duration, [pitch, overtone], {
		square = 0.35,
		amp = [[0.0, 0.0], [0.05, 1.0], [0.6, 0.8], [duration, 0.0]],
		peak = 0.6,
	})
	var breath := Synth.noise_sweep(duration, {
		freq = [[0.0, 1400.0], [duration, 900.0]], q = [[0.0, 2.0]],
		amp = [[0.0, 0.0], [0.1, 0.4], [duration, 0.0]], peak = 0.25,
	}, rng)
	var snort := Synth.noise_sweep(0.22, {
		freq = [[0.0, 500.0], [0.22, 300.0]], q = [[0.0, 1.5]],
		amp = [[0.0, 0.0], [0.02, 1.0], [0.22, 0.0]], peak = 0.5,
	}, rng)
	var out := Synth.mix_into(cry, breath, 0.0, 0.6)
	out = Synth.concat([out, Synth.silence(0.08), snort])
	return Synth.finish(out, 0.75)

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

## Heavy shell shoving through the heap: a dull, low knock with a short tinny
## rattle of the junk it hit, nothing ringing — the clang is saved for the bite.
static func _crane_shove(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.28, 170.0, 0.006, 0.12, rng)
	Synth.mix_into(out, Synth.thump(0.12, 900.0, 0.002, 0.03, rng), 0.02, 0.35)
	Synth.mix_into(out, _metal_ring(0.2, 470.0, 12.0, 0.05, rng), 0.0, 0.2)
	return Synth.finish(out, 0.7)

# --- Scrap forge ----------------------------------------------------------------

## Hammer on a hot lump over the anvil: a hard knock, a bright anvil ring and a
## dull, slightly bent overtone, because nothing here is in tune.
static func _forge_hammer(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.5, 420.0, 0.002, 0.08, rng)
	Synth.mix_into(out, _metal_ring(0.5, 1850.0, 45.0, 0.18, rng), 0.0, 0.55)
	Synth.mix_into(out, _metal_ring(0.45, 2710.0, 40.0, 0.1, rng), 0.0, 0.3)
	Synth.mix_into(out, _metal_ring(0.4, 780.0, 20.0, 0.07, rng), 0.0, 0.3)
	return Synth.finish(out)

## Glowing mash dunked in the water barrel: a spit, then a hiss that sinks and
## bubbles away.
static func _forge_quench(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(1.3, {
		freq = [[0.0, 5200.0], [0.25, 3600.0], [1.3, 1400.0]],
		q = [[0.0, 0.9]],
		highpass = 900.0,
		amp = [[0.0, 0.0], [0.02, 1.0], [0.3, 0.6], [1.3, 0.0]],
	}, rng)
	for bubble in 7:
		var offset := 0.3 + bubble * 0.12 + rng.randf_range(0.0, 0.05)
		var pitch := rng.randf_range(500.0, 900.0)
		var blip := Synth.tones(0.05, [[[0.0, pitch], [0.05, pitch * 1.6]]], {
			amp = [[0.0, 0.0], [0.005, 1.0], [0.05, 0.0]],
		})
		Synth.mix_into(out, blip, offset, 0.2 * (1.0 - bubble / 8.0))
	Synth.mix_into(out, Synth.thump(0.15, 700.0, 0.002, 0.05, rng), 0.0, 0.4)
	return Synth.finish(out, 0.7)

## A shark breaking the surface or going under: a low watery slosh with a
## spray of droplets, softer and rounder than a paddle slap.
static func _shark_splash(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(0.6, {
		freq = [[0.0, 350.0], [0.15, 900.0], [0.6, 300.0]],
		q = [[0.0, 1.2]],
		amp = [[0.0, 0.0], [0.08, 1.0], [0.6, 0.0]],
	}, rng)
	Synth.mix_into(out, Synth.thump(0.25, 160.0, 0.02, 0.1, rng), 0.0, 0.6)
	var spray := Synth.noise_sweep(0.35, {
		freq = [[0.0, 3600.0], [0.35, 2200.0]],
		q = [[0.0, 2.5]],
		amp = [[0.0, 0.0], [0.05, 1.0], [0.35, 0.0]],
		highpass = 1800.0,
	}, rng)
	Synth.mix_into(out, spray, 0.08, 0.2)
	return Synth.finish(out, 0.7)

## A scrap of junk plopping onto the water — a small, soft cousin of the
## shark's splash: shorter, quieter, no spray, just a little wet clunk as it
## settles onto the surface.
static func _trash_splash(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(0.3, {
		freq = [[0.0, 500.0], [0.12, 1100.0], [0.3, 400.0]],
		q = [[0.0, 1.4]],
		amp = [[0.0, 0.0], [0.05, 1.0], [0.3, 0.0]],
	}, rng)
	Synth.mix_into(out, Synth.thump(0.12, 220.0, 0.015, 0.06, rng), 0.0, 0.5)
	return Synth.finish(out, 0.5)

## A part tossed into the crucible: a heavy clunk and a couple of rattles as it
## settles.
static func _crucible_drop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.35, 260.0, 0.003, 0.12, rng)
	Synth.mix_into(out, _metal_ring(0.3, 620.0, 16.0, 0.09, rng), 0.0, 0.4)
	for rattle in 2:
		Synth.mix_into(out, _metal_ring(0.1, rng.randf_range(1300.0, 2200.0), 12.0, 0.03, rng),
				0.09 + rattle * 0.07, 0.3)
	return Synth.finish(out)

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

## The forge's furnace roaring away: a low rumble with a breathy flutter from
## the bellows. Flat level so it loops cleanly.
static func _furnace_loop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.noise_sweep(2.0, {
		freq = [[0.0, 180.0]],
		q = [[0.0, 1.2]],
		lowpass = 900.0,
		amp = [[0.0, 1.0]],
		fade = 0.0,
		peak = 0.7,
	}, rng)
	var flutter := Synth.noise_sweep(2.0, {
		freq = [[0.0, 700.0]],
		q = [[0.0, 2.0]],
		amp = [[0.0, 1.0]],
		fade = 0.0,
		peak = 0.3,
	}, rng)
	for i in out.size():
		var t := float(i) / Synth.SAMPLE_RATE
		out[i] += flutter[i] * (0.5 + 0.5 * sin(TAU * 3.0 * t))
	return Synth.finish(out, 0.6, 0.0)

# --- Landmark ambience ----------------------------------------------------------

## A seagull over the fishing port: two squawky "kyow" cries that slide down.
static func _gull_cry() -> PackedFloat32Array:
	var kyow := func(duration: float, top: float) -> PackedFloat32Array:
		return Synth.tones(duration, [[[0.0, top * 0.8], [duration * 0.2, top], [duration, top * 0.62]],
				[[0.0, top * 1.6], [duration * 0.2, top * 2.0], [duration, top * 1.24]]], {
			square = 0.4,
			amp = [[0.0, 0.0], [0.02, 1.0], [duration * 0.7, 0.7], [duration, 0.0]],
			tremolo = [28.0, 0.2],
			peak = 0.6,
		})
	return Synth.finish(Synth.concat([kyow.call(0.24, 1500.0), Synth.silence(0.07), kyow.call(0.32, 1350.0)]), 0.6)

## The lighthouse foghorn: a long, low, slightly sour two-tone blast with a
## breathy edge, swelling in and dying away.
static func _foghorn(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var duration := 1.9
	var out := Synth.tones(duration, [[[0.0, 92.0], [0.2, 98.0], [duration, 94.0]], [[0.0, 139.0], [0.2, 147.0], [duration, 141.0]]], {
		square = 0.55,
		amp = [[0.0, 0.0], [0.25, 1.0], [1.4, 0.9], [duration, 0.0]],
		peak = 0.7,
	})
	var breath := Synth.noise_sweep(duration, {
		freq = [[0.0, 400.0]], q = [[0.0, 1.5]],
		amp = [[0.0, 0.0], [0.25, 1.0], [1.4, 0.8], [duration, 0.0]], peak = 0.3,
	}, rng)
	Synth.mix_into(out, breath, 0.0, 0.5)
	return Synth.finish(out, 0.75)

## A crow in the graveyard: two hoarse, raspy caws.
static func _crow_caw(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var caw := func(duration: float, pitch: float) -> PackedFloat32Array:
		var voice := Synth.tones(duration, [[[0.0, pitch], [duration * 0.3, pitch * 1.08], [duration, pitch * 0.8]],
				[[0.0, pitch * 2.0], [duration * 0.3, pitch * 2.16], [duration, pitch * 1.6]]], {
			square = 0.8,
			amp = [[0.0, 0.0], [0.02, 1.0], [duration * 0.6, 0.8], [duration, 0.0]],
			tremolo = [40.0, 0.5],
			peak = 0.5,
		})
		var rasp := Synth.noise_sweep(duration, {
			freq = [[0.0, 1300.0], [duration, 900.0]], q = [[0.0, 3.0]],
			amp = [[0.0, 0.0], [0.02, 1.0], [duration, 0.0]], peak = 0.5,
		}, rng)
		return Synth.mix_into(voice, rasp, 0.0, 0.7)
	return Synth.finish(Synth.concat([caw.call(0.28, 520.0), Synth.silence(0.12), caw.call(0.3, 480.0)]), 0.6)

## A cricket in the fields: three quick high trills.
static func _cricket_chirp() -> PackedFloat32Array:
	var trill := Synth.tones(0.07, [[[0.0, 4400.0]]], {
		amp = [[0.0, 0.0], [0.005, 1.0], [0.07, 0.0]],
		tremolo = [90.0, 0.9],
		peak = 0.5,
	})
	return Synth.concat([trill, Synth.silence(0.06), trill, Synth.silence(0.06), trill])

## An oil pumpjack turning over the bottom of its stroke: a dull clunk and a
## dry, groaning creak from the walking beam's bearing.
static func _pumpjack_creak(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := Synth.thump(0.3, 240.0, 0.004, 0.12, rng)
	var creak := Synth.tones(0.5, [[[0.0, 210.0], [0.25, 260.0], [0.5, 190.0]]], {
		square = 0.7,
		amp = [[0.0, 0.0], [0.06, 0.8], [0.35, 0.6], [0.5, 0.0]],
		tremolo = [34.0, 0.8],
		peak = 0.5,
	})
	Synth.mix_into(out, creak, 0.05, 0.5)
	Synth.mix_into(out, _metal_ring(0.25, 940.0, 18.0, 0.07, rng), 0.0, 0.25)
	return Synth.finish(out, 0.6)
