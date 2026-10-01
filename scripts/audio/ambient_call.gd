class_name AmbientCall
extends AudioStreamPlayer2D
## A SoundLibrary one-shot a landmark repeats every now and then: gulls over the
## port, the lighthouse foghorn, a crow in the graveyard, crickets in the
## fields. Positional, so it only carries as far as `max_distance`.

@export var sound_name: StringName
## Seconds between calls, re-rolled after each one.
@export var interval_range: Vector2 = Vector2(6.0, 14.0)
@export var pitch_variation: float = 0.08

var _wait: float = 0.0

func _ready() -> void:
	stream = Sfx.stream(sound_name)
	bus = SoundLibrary.bus_for(sound_name)
	_wait = randf_range(0.0, interval_range.y)

func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(interval_range.x, interval_range.y)
	pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	play()
