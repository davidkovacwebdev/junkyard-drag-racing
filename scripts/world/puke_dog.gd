class_name PukeDog
extends Node2D
## A stray that smells a fresh puddle of sick (PukePuddle) and comes for it:
## it trots in from off to one side, stands over the puddle lapping it up
## (`dog_lick`) while it shrinks away, gives one happy bark and trots off the
## other way, gone. PlayerCar sends one after some of its puke stops.
##
## Drawn like the yard dog (YardDog) but scruffier: greyer, no collar, and
## its tongue flicking out as it licks (its one gag). Origin on the ground
## under its feet so it Y-sorts against the car.

enum State { COMING, LICKING, LEAVING }

const FUR := Color(0.5, 0.47, 0.42)
const EAR := Color(0.32, 0.29, 0.26)
const TONGUE := Color(0.86, 0.45, 0.5)

## Where it turns up, relative to the puddle (mirrored to a random side), and
## how far it wanders off afterwards before it's gone.
const ARRIVE_FROM := Vector2(720.0, 90.0)
const LEAVE_DISTANCE := 760.0
const TROT_SPEED := 230.0
## It stands this far behind the puddle (towards where it came from) so its
## snout is over the middle, and a touch in front of it so it sorts on top.
const STAND_OFF := Vector2(52.0, 6.0)
const LICK_SECONDS := 4.5
const LICK_INTERVAL := 0.42
const LICK_DB := -6.0
const BARK_DB := -6.0
const STRIDE_RATE := 0.06
const WAG_RATE := 12.0
## Lowering the head to the puddle: how far it drops.
const HEAD_DOWN := 34.0

var _state := State.COMING
var _puddle: PukePuddle
var _stand := Vector2.ZERO
var _exit := Vector2.ZERO
var _facing := 1.0
var _stride := 0.0
var _time := 0.0
var _licking_left := 0.0
var _lick_timer := 0.0
var _tongue := 0.0
var _moving := false

## Sends a stray at `puddle`, from whichever side. Added next to the car (the
## Y-sorted world), not under the decal layer the puddle lives on.
static func send_to(puddle: PukePuddle, parent: Node) -> PukeDog:
	var dog := PukeDog.new()
	var side := -1.0 if randf() < 0.5 else 1.0
	dog._puddle = puddle
	dog._stand = puddle.global_position + Vector2(STAND_OFF.x * side, STAND_OFF.y)
	dog._exit = puddle.global_position - Vector2(LEAVE_DISTANCE * side, -ARRIVE_FROM.y)
	dog._facing = -side
	parent.add_child(dog)
	dog.global_position = puddle.global_position + Vector2(ARRIVE_FROM.x * side, ARRIVE_FROM.y)
	return dog

func _process(delta: float) -> void:
	_time += delta
	_tongue = maxf(0.0, _tongue - delta * 5.0)
	match _state:
		State.COMING:
			if _trot_to(_stand, delta):
				_state = State.LICKING
				_licking_left = LICK_SECONDS
				_lick_timer = 0.0
				if is_instance_valid(_puddle):
					_puddle.lick_away(LICK_SECONDS)
		State.LICKING:
			_licking_left -= delta
			_lick_timer -= delta
			if _lick_timer <= 0.0:
				_lick_timer = LICK_INTERVAL
				_tongue = 1.0
				Sfx.play_at(&"dog_lick", global_position, LICK_DB, 0.12)
			if _licking_left <= 0.0:
				_state = State.LEAVING
				_facing = signf(_exit.x - global_position.x)
				Sfx.play_at(&"dog_bark", global_position, BARK_DB, 0.1)
		State.LEAVING:
			if _trot_to(_exit, delta):
				queue_free()
	queue_redraw()

## A step toward `target` at a trot, facing it. True once it's there.
func _trot_to(target: Vector2, delta: float) -> bool:
	var to_go := target - global_position
	_moving = to_go.length() > 2.0
	if not _moving:
		return true
	if absf(to_go.x) > 4.0:
		_facing = signf(to_go.x)
	var step := minf(TROT_SPEED * delta, to_go.length())
	global_position += to_go.normalized() * step
	_stride += step * STRIDE_RATE
	return false

## Shadow, two legs, tail, body, belly shade, head and its floppy ear, as
## YardDog draws them. Licking, the head drops to the ground and the tongue
## flicks out of the snout on every lap.
func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(4.0, 0.0), 36.0, 7.0), UiPalette.SHADOW)
	var bounce := -absf(sin(_stride * PI)) * 5.0 if _moving else 0.0
	draw_set_transform(Vector2(0.0, bounce), 0.0, Vector2(_facing, 1.0))
	var swing := sin(_stride * PI) * 10.0 if _moving else 0.0
	draw_colored_polygon(FlatProps.sliver(Vector2(-18.0, -24.0), Vector2(-18.0 - swing, -bounce), 8.0), FUR.darkened(0.2))
	draw_colored_polygon(FlatProps.sliver(Vector2(18.0, -24.0), Vector2(18.0 + swing, -bounce), 8.0), FUR.darkened(0.2))
	var licking := _state == State.LICKING
	var wag := sin(_time * WAG_RATE) * (14.0 if licking else 8.0)
	draw_colored_polygon(FlatProps.sliver(Vector2(-26.0, -40.0), Vector2(-44.0, -58.0 + wag), 7.0), FUR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30.0, -44.0), Vector2(22.0, -48.0), Vector2(28.0, -22.0), Vector2(-28.0, -20.0),
	]), FUR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-29.0, -28.0), Vector2(27.0, -28.0), Vector2(28.0, -22.0), Vector2(-28.0, -20.0),
	]), FUR.darkened(0.18))
	var head := Vector2(0.0, HEAD_DOWN) if licking else Vector2.ZERO
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(18.0, -62.0), head + Vector2(36.0, -68.0), head + Vector2(44.0, -58.0),
		head + Vector2(60.0, -54.0), head + Vector2(60.0, -42.0), head + Vector2(38.0, -40.0), head + Vector2(20.0, -44.0),
	]), FUR)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(22.0, -64.0), head + Vector2(36.0, -66.0), head + Vector2(30.0, -40.0),
	]), EAR)
	if licking and _tongue > 0.0:
		var tip := head + Vector2(58.0, -40.0 + 10.0 * _tongue)
		draw_colored_polygon(FlatProps.sliver(head + Vector2(54.0, -44.0), tip, 6.0), TONGUE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
