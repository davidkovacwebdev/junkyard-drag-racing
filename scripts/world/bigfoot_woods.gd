class_name BigfootWoods
extends Node2D
## The forest grove on the peninsula road where Bigfoot lives. Every night,
## when the car comes near, he steps out of the trees and ambles across the
## road. Get close and he howls (`bigfoot_howl`) and bolts into the woods,
## stomping (`bigfoot_stomp`) and leaving a trail of big footprints. Ram him
## and his leg comes off with a `flesh_splat`: it flies off as a part orb (the
## `BigfootLeg` child, a HiddenPartPickup kept out of the tree until then) and
## he hops away on the other one, bleeding a trail of blood. Until his leg is
## knocked off he comes back the next night; once it's picked up (claim
## `bigfoot_leg`) he's gone for good. A leg left lying is lost on a map
## reload, and he turns up again with it.
##
## Paths are in this node's space. The prints stay until morning.

enum State { WAITING, CROSSING, FLEEING, DONE_TONIGHT }

## From the treeline across the road.
@export var cross_path: PackedVector2Array = PackedVector2Array()
## Where he runs once spooked, deeper into the woods.
@export var flee_path: PackedVector2Array = PackedVector2Array()

const TRIGGER_RADIUS := 1300.0
const SPOOK_RADIUS := 560.0
const AMBLE_SPEED := 110.0
## Just under the car's off-road top speed, so a chase can catch him.
const RUN_SPEED := 340.0
const HOP_SPEED := 260.0
const HIT_RADIUS := 85.0
const HIT_MIN_CAR_SPEED := 150.0
const NIGHT_FROM := 0.9
const DAY_BELOW := 0.1
const HOWL_DB := -2.0
const AMBLE_STOMP_DB := -12.0
const RUN_STOMP_DB := -5.0
const LEG_LAND_DB := -2.0
const SPLAT_DB := -2.0
const LEG_ARC := 120.0
const LEG_FLIGHT := 0.7
const LEG_THROW := 220.0
const HIP_HEIGHT := 70.0
const VANISH_SECONDS := 0.6
const LEG_CLAIM := "bigfoot_leg"

const BLOOD_HOLD_SECONDS := 180.0
const BLOOD_DROP_RADIUS := Vector2(8.0, 14.0)
## Extra drops scattered around each hop, on top of the one under his foot.
const BLOOD_SPATTER := 2

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
var _blood_trail: BloodTrail = null
var _delegged := false

func _ready() -> void:
	_leg = get_node_or_null("BigfootLeg") as HiddenPartPickup
	if WorldState.is_claimed(LEG_CLAIM) or _leg == null or _leg.is_queued_for_deletion():
		_leg = null
		set_process(false)
		return
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
			if not _check_hit() and _player_within(_bigfoot.global_position, SPOOK_RADIUS):
				_bolt()
		State.FLEEING:
			_check_hit()

func _player_within(point: Vector2, radius: float) -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	return _player != null and _player.global_position.distance_to(point) <= radius

func _step_out() -> void:
	_state = State.CROSSING
	_bigfoot = Bigfoot.new()
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
	_bigfoot.walk_along(_to_global(flee_path), HOP_SPEED if _delegged else RUN_SPEED)

## Whether the car just rammed him (and took his leg off).
func _check_hit() -> bool:
	if _delegged or not _player_within(_bigfoot.global_position, HIT_RADIUS):
		return false
	var car_velocity: Vector2 = _player.get("velocity")
	if car_velocity.length() < HIT_MIN_CAR_SPEED:
		return false
	_knock_leg_off(car_velocity)
	return true

func _knock_leg_off(car_velocity: Vector2) -> void:
	_delegged = true
	var ground := _bigfoot.global_position
	var landing := ground + car_velocity.normalized() * LEG_THROW
	add_child(_leg)
	_leg.launch(ground + Vector2(0.0, -HIP_HEIGHT), landing, LEG_ARC, LEG_FLIGHT)
	_bigfoot.one_legged = true
	Sfx.play_at(&"flesh_splat", ground, SPLAT_DB)
	BloodSpray.spray(self, ground + Vector2(0.0, -HIP_HEIGHT), 800.0)
	_spill_blood(ground)
	get_tree().create_timer(LEG_FLIGHT).timeout.connect(
			Sfx.play_at.bind(&"bigfoot_stomp", landing, LEG_LAND_DB))
	if _state == State.CROSSING:
		_bolt()
	else:
		Sfx.play_at(&"bigfoot_howl", ground, HOWL_DB)
		_bigfoot.set_speed(HOP_SPEED)

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
		if footprint != _blood_trail:
			footprint.queue_free()
	if _delegged:
		set_process(false)

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
		if oldest == _blood_trail:
			oldest = _footprints.get_child(1)
		_footprints.remove_child(oldest)
		oldest.queue_free()
	if _delegged:
		_spill_blood(at)

func _spill_blood(at: Vector2) -> void:
	if _blood_trail == null:
		_blood_trail = BloodTrail.new()
		_blood_trail.hold_time = BLOOD_HOLD_SECONDS
		_footprints.add_child(_blood_trail)
		_footprints.move_child(_blood_trail, 0)
	_blood_trail.add_drop(at, BLOOD_DROP_RADIUS.y * randf_range(0.8, 1.1))
	for i in BLOOD_SPATTER:
		var scatter := Vector2(randf_range(-30.0, 30.0), randf_range(-14.0, 14.0))
		_blood_trail.add_drop(at + scatter, BLOOD_DROP_RADIUS.x * randf_range(0.7, 1.1))

func _to_global(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(to_global(point))
	return out
