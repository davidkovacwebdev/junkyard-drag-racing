class_name PenGull
extends Bird
## A seagull wheeling over the crane pen: the beach's gull (Bird), only it never
## lands. It glides across the sky in a slow bob, flapping in short bursts and
## holding its wings out flat in between, and once it's well past the pen it
## turns up again on the far side at a new height and speed. Now and then it
## cries (a `gull_cry` AmbientCall riding along with it).

## How fast it crosses, picked fresh every pass.
@export var speed_range: Vector2 = Vector2(80.0, 150.0)
## Height band it flies in, in its parent's space (the pen's ground is 0).
@export var height_range: Vector2 = Vector2(-980.0, -600.0)
## How far either side of the pen's middle it goes before turning up again on
## the other side: past the edge of any window.
@export var span: float = 1300.0

const BOB_HEIGHT := 14.0
const BOB_SPEED := 0.9
const FLAP_BURST := Vector2(0.8, 1.6)
const GLIDE_TIME := Vector2(1.5, 3.2)
const SIZE := 2.0

var _speed: float = 0.0
var _base_y: float = 0.0
var _bob: float = 0.0
## Seconds left flapping (> 0) or gliding (< 0).
var _beat: float = 0.0

func _ready() -> void:
	super._ready()
	species = Species.GULL
	_flying = true
	scale = Vector2.ONE * SIZE
	_new_pass(randf_range(-span, span))
	var cry := AmbientCall.new()
	cry.sound_name = &"gull_cry"
	cry.interval_range = Vector2(8.0, 20.0)
	cry.volume_db = -10.0
	add_child(cry)

## Start a crossing at `x`, heading back across the pen.
func _new_pass(x: float) -> void:
	_facing = -signf(x) if x != 0.0 else 1.0
	_speed = randf_range(speed_range.x, speed_range.y)
	_base_y = randf_range(height_range.x, height_range.y)
	_bob = randf() * TAU
	_beat = randf_range(FLAP_BURST.x, FLAP_BURST.y)
	position = Vector2(x, _base_y)

## Replaces Bird's take-off flight: straight across with a bob, flapping and
## gliding by turns, round again past the far side.
func _fly(delta: float) -> void:
	_bob += delta * BOB_SPEED
	position.x += _facing * _speed * delta
	position.y = _base_y + sin(_bob) * BOB_HEIGHT
	if _beat > 0.0:
		_flap += FLAP_SPEED * delta
		_beat -= delta
		if _beat <= 0.0:
			_beat = -randf_range(GLIDE_TIME.x, GLIDE_TIME.y)
	else:
		# Wings out flat: ease the beat round to where the tips are level.
		_flap = lerp_angle(_flap, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		_beat += delta
		if _beat >= 0.0:
			_beat = randf_range(FLAP_BURST.x, FLAP_BURST.y)
	if absf(position.x) > span:
		_new_pass(signf(position.x) * span)
