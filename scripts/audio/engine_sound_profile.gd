class_name EngineSoundProfile
extends Resource
## How one kind of engine sounds, played live by EngineSound. Profiles live in
## res://sounds/engines/<engine part id>.tres and are found by the engine's id
## (see `for_engine`) rather than stored on the part, so a save written before a
## profile existed still picks it up.
##
## "Firing frequency" is the buzz fundamental — roughly rpm / 60 * cylinders / 2.
## `rpm` 0 is idle, 1 is flat out.

const PROFILE_DIRECTORY := "res://sounds/engines/"

@export_group("Pitch")
@export var idle_frequency: float = 45.0
@export var max_frequency: float = 170.0
## Random pitch wobble — roughness. Rate is how fast it wanders.
@export var jitter: float = 0.015
@export var jitter_rate: float = 60.0
## Slow lumpy wobble for big, lazy engines.
@export var knock: float = 0.04
@export var knock_rate: float = 14.0

@export_group("Tone")
## 0 removes the piston buzz entirely (a sail has no pistons).
@export var buzz_level: float = 1.0
@export var harmonics: int = 18
## Lower = brighter and rougher.
@export var rolloff: float = 1.35
## Sine an octave under the firing frequency — low-end thump.
@export var sub_level: float = 0.3
@export var drive: float = 0.12
@export var noise_level: float = 0.06
@export var noise_cutoff: float = 1200.0
@export var cutoff_idle: float = 600.0
@export var cutoff_max: float = 1500.0
## Body/exhaust resonance. 0 frequency turns it off.
@export var resonance_frequency: float = 0.0
@export var resonance_q: float = 6.0
@export var resonance_gain: float = 0.3
## Pure tone riding at `whine_ratio` × the firing frequency — turbines, blowers.
@export var whine_level: float = 0.0
@export var whine_ratio: float = 8.0
## Amplitude pulsing at `chuff_ratio` × the firing frequency — steam chuffs.
@export var chuff_level: float = 0.0
@export var chuff_ratio: float = 0.25
## Higher = shorter, snappier pulses (4 is a soft steam chuff, 12+ a canvas snap).
@export var chuff_sharpness: float = 4.0
## Slow random swells in loudness — wind gusting. Rate is how often, in Hz.
@export var gust_level: float = 0.0
@export var gust_rate: float = 0.6

@export_group("Level")
@export var idle_volume: float = 0.45
@export var max_volume: float = 0.9
## Extra loudness and brightness while throttle is held, on top of rpm.
@export var throttle_boost: float = 0.25

static var _loaded: Dictionary = {}

## The profile for an engine part, or a plain petrol engine when it has none.
## Null only when there's no engine at all — a car with no engine is silent.
static func for_engine(engine: EnginePartData) -> EngineSoundProfile:
	if engine == null:
		return null
	if _loaded.has(engine.id):
		return _loaded[engine.id]
	var path := PROFILE_DIRECTORY + String(engine.id) + ".tres"
	var profile: EngineSoundProfile = load(path) if ResourceLoader.exists(path) else EngineSoundProfile.new()
	_loaded[engine.id] = profile
	return profile
