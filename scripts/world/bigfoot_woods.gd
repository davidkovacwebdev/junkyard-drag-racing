class_name BigfootWoods
extends Node2D
## The forest grove on the peninsula road where Bigfoot lives. Once a night,
## when the car comes near, he steps out of the trees and ambles across the
## road. Get close and he howls (`bigfoot_howl`) and bolts into the woods,
## stomping (`bigfoot_stomp`) and leaving a trail of big footprints. Follow it
## and part way along he loses his leg: it thuds down as a part orb (the
## `BigfootLeg` child, a HiddenPartPickup kept out of the tree until then),
## and he hops off on the other one. Once the leg's been taken he's one-legged
## every night after.
##
## Paths are in this node's space. The prints stay until morning.

enum State { WAITING, CROSSING, FLEEING, DONE_TONIGHT }

## From the treeline across the road.
@export var cross_path: PackedVector2Array = PackedVector2Array()
## Where he runs once spooked, deeper into the woods.
@export var flee_path: PackedVector2Array = PackedVector2Array()
## The `flee_path` point where the leg comes off.
@export var leg_drop_index: int = 3

const TRIGGER_RADIUS := 1300.0
const SPOOK_RADIUS := 560.0
const AMBLE_SPEED := 110.0
const RUN_SPEED := 430.0
const NIGHT_FROM := 0.9
const DAY_BELOW := 0.1
const HOWL_DB := -2.0
const AMBLE_STOMP_DB := -12.0
const RUN_STOMP_DB := -5.0
const LEG_LAND_DB := -2.0
const LEG_ARC := 120.0
const LEG_FLIGHT := 0.7
const VANISH_SECONDS := 0.6

const MAX_PRINTS := 24
## Sideways gap between his left and right prints.
const PRINT_SPREAD := 22.0
const PRINT_COLOR := Color(0.28, 0.4, 0.23)
const PRINT_SHAPE := [
	Vector2(-22.0, -9.0), Vector2(14.0, -13.0), Vector2(26.0, -5.0),
	Vector2(24.0, 9.0), Vector2(-16.0, 11.0), Vector2(-26.0, 1.0),
]

@onready var _footprints: Node2D = $Footprints

var _state := State.WAITING
var _bigfoot: Bigfoot = null
var _player: Node2D = null
var _leg: HiddenPartPickup = null
var _left_foot := false

func _ready() -> void:
	_leg = get_node_or_null("BigfootLeg") as HiddenPartPickup
	if _leg != null:
		if _leg.is_queued_for_deletion():
			_leg = null
		else:
			remove_child(_leg)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _leg != null and not _leg.is_inside_tree():
		_leg.free()

func _process(_delta: float) -> void:
	var night := DayNightCycle.get_night_factor()
	if night < DAY_BELOW:
		if _state != State.WAITING:
			_reset_for_day()
		return
	match _state:
		State.WAITING:
			if night >= NIGHT_FROM and _player_within(global_position, TRIGGER_RADIUS):
				_step_out()
		State.CROSSING:
			if _player_within(_bigfoot.global_position, SPOOK_RADIUS):
				_bolt()

func _player_within(point: Vector2, radius: float) -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	return _player != null and _player.global_position.distance_to(point) <= radius

func _step_out() -> void:
	_state = State.CROSSING
	_bigfoot = Bigfoot.new()
	_bigfoot.one_legged = _leg == null
	_bigfoot.position = cross_path[0]
	_bigfoot.footfall.connect(_on_footfall)
	_bigfoot.finished.connect(_bolt)
	add_child(_bigfoot)
	_bigfoot.walk_along(_to_global(cross_path), AMBLE_SPEED)

func _bolt() -> void:
	if _state != State.CROSSING:
		return
	_state = State.FLEEING
	Sfx.play_at(&"bigfoot_howl", _bigfoot.global_position, HOWL_DB)
	_bigfoot.finished.disconnect(_bolt)
	_bigfoot.finished.connect(_vanish)
	_bigfoot.waypoint_reached.connect(_on_flee_waypoint)
	_bigfoot.walk_along(_to_global(flee_path), RUN_SPEED)

func _on_flee_waypoint(index: int) -> void:
	if index != leg_drop_index or _leg == null or _leg.is_inside_tree():
		return
	var ground := _bigfoot.global_position
	add_child(_leg)
	_leg.launch(ground + Vector2(0.0, -90.0), ground, LEG_ARC, LEG_FLIGHT)
	_bigfoot.one_legged = true
	get_tree().create_timer(LEG_FLIGHT).timeout.connect(
			Sfx.play_at.bind(&"bigfoot_stomp", ground, LEG_LAND_DB))

func _vanish() -> void:
	_state = State.DONE_TONIGHT
	var fade := _bigfoot.create_tween()
	fade.tween_property(_bigfoot, "modulate:a", 0.0, VANISH_SECONDS)
	fade.tween_callback(_bigfoot.queue_free)
	_bigfoot = null

func _reset_for_day() -> void:
	_state = State.WAITING
	if is_instance_valid(_bigfoot):
		_bigfoot.queue_free()
	_bigfoot = null
	for footprint in _footprints.get_children():
		footprint.queue_free()

func _on_footfall(at: Vector2, heading: Vector2) -> void:
	var running := _state == State.FLEEING
	Sfx.play_at(&"bigfoot_stomp", at, RUN_STOMP_DB if running else AMBLE_STOMP_DB, 0.1)
	var side := 0.0
	if not _bigfoot.one_legged:
		_left_foot = not _left_foot
		side = PRINT_SPREAD * (1.0 if _left_foot else -1.0)
	var footprint := Polygon2D.new()
	footprint.color = PRINT_COLOR
	footprint.polygon = PackedVector2Array(PRINT_SHAPE)
	footprint.position = _footprints.to_local(at + heading.orthogonal() * side)
	footprint.rotation = heading.angle()
	_footprints.add_child(footprint)
	if _footprints.get_child_count() > MAX_PRINTS:
		var oldest := _footprints.get_child(0)
		_footprints.remove_child(oldest)
		oldest.queue_free()

func _to_global(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(to_global(point))
	return out
