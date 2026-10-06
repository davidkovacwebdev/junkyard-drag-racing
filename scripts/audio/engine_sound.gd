class_name EngineSound
extends AudioStreamPlayer2D
## A running engine, synthesized live from an EngineSoundProfile — same voice as
## Synth.engine(), but fed every frame so pitch and tone follow the car instead
## of being baked in. Whoever owns the car sets `rpm` (0 idle .. 1 flat out)
## and `throttle` (0..1); this does the rest.
##
## The samples come from a native EngineVoice (rust/src/engine_voice.rs), which
## keeps a live engine cheap enough to run one per car in a race.

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

var _start_blip: float = 0.0

var _playback: AudioStreamGeneratorPlayback
var _voice := EngineVoice.new()
var _smoothed_rpm: float = 0.0
var _smoothed_throttle: float = 0.0

func _ready() -> void:
	bus = AudioSettings.CARS
	if profile == null:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = Synth.SAMPLE_RATE
	generator.buffer_length = BUFFER_SECONDS
	stream = generator
	_voice.configure(profile, randi())
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
		_playback.push_buffer(_voice.synthesize(frames, _smoothed_rpm, _smoothed_throttle, master_level))
