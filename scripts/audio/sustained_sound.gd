class_name SustainedSound
extends AudioStreamPlayer2D
## A looping SoundLibrary sound that's held on and off — a horn while H is down,
## tyres screeching while the car skids, rain while it rains. Call
## `set_level()` every frame with how loud it should be (0 = off); the player
## eases toward it so starting and stopping never clicks, and stops the stream
## outright once it's silent.

@export var sound_name: StringName
@export var fade_in_time: float = 0.03
@export var fade_out_time: float = 0.08
## Once started, stays on at least this long — a tap of the horn still honks.
@export var min_on_time: float = 0.0
@export var base_volume_db: float = 0.0
## Restart the loop from its beginning each time it turns on (a horn), rather
## than picking up wherever the loop happens to be (noise beds don't care).
@export var restart_on_start: bool = false

var _target_level: float = 0.0
var _level: float = 0.0
var _on_time: float = 0.0

func _ready() -> void:
	stream = Sfx.stream(sound_name)
	bus = SoundLibrary.bus_for(sound_name)
	volume_db = -80.0

func set_level(level: float) -> void:
	_target_level = clampf(level, 0.0, 1.0)

func set_active(active: bool) -> void:
	set_level(1.0 if active else 0.0)

func _process(delta: float) -> void:
	var target := _target_level
	if _level > 0.0 and _on_time < min_on_time:
		target = maxf(target, 1.0)
	if target > _level:
		_level = minf(target, _level + delta / maxf(fade_in_time, 0.001))
	else:
		_level = maxf(target, _level - delta / maxf(fade_out_time, 0.001))

	if _level > 0.0:
		if not playing:
			play(0.0 if restart_on_start else randf() * stream.get_length())
			_on_time = 0.0
		_on_time += delta
		volume_db = base_volume_db + linear_to_db(_level)
	elif playing:
		stop()
