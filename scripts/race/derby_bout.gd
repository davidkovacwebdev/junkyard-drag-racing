class_name DerbyBout
extends RefCounted
## One demolition derby bout: the cars in one walled pit, all on the same
## collision layer, so every hit is real physics and real CarPartDamage. Each
## car is driven by a dumb derby brain: pick a rival, drive at it (reversing
## if it's behind, rear first like a real derby driver), and pick again every
## couple of seconds or when about to hit a wall.
##
## A car is out when its body breaks, it lies on its roof with a rival still
## on it, it loses every wheel, or it sits still too long. A car left alone on
## its roof is dropped back in upright at the far end of the pit instead. A knockout is credited to the last rival
## that touched the car within KILL_CREDIT_TIME. Used by the derby race
## (DerbySetup), which calls step() every physics frame.

signal knocked_out(driver: Driver, reason: String, killer: Driver)
## Every rival is out and `driver` is the only car left running.
signal last_one_standing(driver: Driver)
## A car left alone on its roof was dropped back in at the far end of the pit.
signal respawned(driver: Driver)

## The cars' own layer: they hit each other, the floor and the walls.
const CAR_LAYER := 128
const ARENA_LAYERS := 2 | 64
const RETARGET_TIME := Vector2(1.2, 2.6)
## Turn around this far short of a wall rather than grind against it.
const WALL_TURN_DISTANCE := 260.0
## Lying past this angle for ROOF_TIME seconds counts as on its roof.
const ROOF_ANGLE := 2.0
const ROOF_TIME := 3.0
## Once ROOF_TIME is up, a car no rival has touched for this long is dropped
## back in rather than knocked out, so a lone flip isn't the end of a bout.
const ROOF_QUIET_TIME := 2.0
## How far in from a wall, and how high up, a flipped car is dropped back in.
const RESPAWN_WALL_INSET := 350.0
const RESPAWN_DROP_HEIGHT := 120.0
const STUCK_SPEED := 30.0
const STUCK_TIME := 7.0
## Share of each part's durability it enters the pit with. Head-on hits in
## one line are slow, so at full strength nothing ever breaks.
const DERBY_DURABILITY := 0.3
const KILL_CREDIT_TIME := 5.0

class Driver:
	var car_name := ""
	var car: CarAssembler.AssembledCar
	## Each wheel's own forward spin target, flipped to reverse.
	var full_spin: Dictionary = {}
	var direction := 1.0
	var retarget_in := 0.0
	var roof_time := 0.0
	var stuck_time := 0.0
	var out := false
	var kills := 0
	var last_hitter: Driver = null
	var last_hit_time := -INF
	## The body's height when it was standing on the pit floor.
	var floor_y := 0.0

var drivers: Array[Driver] = []
var elapsed := 0.0
var _driver_of_part: Dictionary = {}
var _arena_left := 0.0
var _arena_right := 0.0
var _decided := false

func _init(arena_left: float, arena_right: float) -> void:
	_arena_left = arena_left
	_arena_right = arena_right

func add_car(car_name: String, car: CarAssembler.AssembledCar) -> Driver:
	CarAutosteer.switch_off(car.body)
	for part in [car.body] + car.wheels:
		part.collision_layer = CAR_LAYER
		part.collision_mask = CAR_LAYER | ARENA_LAYERS
		part.contact_monitor = true
		part.max_contacts_reported = 4
		var tracker := CarPartDamage.of(part)
		if tracker != null:
			tracker.max_durability *= DERBY_DURABILITY
			tracker.current_durability = tracker.max_durability
	var driver := Driver.new()
	driver.car_name = car_name
	driver.car = car
	driver.floor_y = car.body.global_position.y
	for part in [car.body] + car.wheels:
		_driver_of_part[part] = driver
	for wheel in car.wheels:
		driver.full_spin[wheel] = wheel.target_angular_velocity
	drivers.append(driver)
	return driver

func step(delta: float) -> void:
	elapsed += delta
	for driver in drivers:
		if not driver.out:
			_record_hits(driver)
	for driver in drivers:
		if driver.out:
			continue
		var reason := _knockout_reason(driver, delta)
		if reason == "on its roof" and elapsed - driver.last_hit_time >= ROOF_QUIET_TIME:
			_respawn(driver)
		elif not reason.is_empty():
			_knock_out(driver, reason)
			continue
		_drive(driver, delta)
	var still_running := running()
	if still_running.size() == 1 and drivers.size() > 1 and not _decided:
		_decided = true
		last_one_standing.emit(still_running[0])

func running() -> Array[Driver]:
	return drivers.filter(func(driver: Driver) -> bool: return not driver.out)

## Share of durability left over the body and wheels still on.
static func health(driver: Driver) -> float:
	var total := 0.0
	var parts := 0
	for part in [driver.car.body] + driver.car.wheels:
		parts += 1
		var tracker := CarPartDamage.of(part) if is_instance_valid(part) else null
		if tracker != null and not tracker.is_broken:
			total += tracker.current_durability / tracker.max_durability
	return total / maxi(parts, 1)

func stop(driver: Driver) -> void:
	driver.out = true
	_set_spin(driver, 0.0)

func _record_hits(driver: Driver) -> void:
	for part in [driver.car.body] + driver.car.wheels:
		if not is_instance_valid(part):
			continue
		for other in (part as RigidBody2D).get_colliding_bodies():
			var hitter: Driver = _driver_of_part.get(other)
			if hitter != null and hitter != driver:
				driver.last_hitter = hitter
				driver.last_hit_time = elapsed

func _drive(driver: Driver, delta: float) -> void:
	var body := driver.car.body
	driver.retarget_in -= delta
	var heading_into_wall := (driver.direction > 0.0 and body.global_position.x > _arena_right - WALL_TURN_DISTANCE) \
			or (driver.direction < 0.0 and body.global_position.x < _arena_left + WALL_TURN_DISTANCE)
	if driver.retarget_in <= 0.0 or heading_into_wall:
		driver.retarget_in = randf_range(RETARGET_TIME.x, RETARGET_TIME.y)
		var target := _pick_target(driver)
		if heading_into_wall:
			driver.direction = -driver.direction
		elif target != null:
			driver.direction = signf(target.global_position.x - body.global_position.x)
		_set_spin(driver, driver.direction)

## A random rival still running, favouring the closer ones.
func _pick_target(driver: Driver) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for other in drivers:
		if other == driver or other.out or not is_instance_valid(other.car.body):
			continue
		var score := absf(other.car.body.global_position.x - driver.car.body.global_position.x) * randf_range(0.5, 1.5)
		if score < best_score:
			best_score = score
			best = other.car.body
	return best

func _set_spin(driver: Driver, direction: float) -> void:
	for wheel in driver.full_spin:
		if is_instance_valid(wheel):
			(wheel as CarWheel).target_angular_velocity = driver.full_spin[wheel] * direction

## Why the car is out, or empty while it's still running.
func _knockout_reason(driver: Driver, delta: float) -> String:
	var body := driver.car.body
	if not is_instance_valid(body):
		return "wrecked"
	if not driver.car.wheels.any(func(wheel: CarWheel) -> bool: return is_instance_valid(wheel)):
		return "no wheels"
	driver.roof_time = driver.roof_time + delta if absf(wrapf(body.rotation, -PI, PI)) > ROOF_ANGLE else 0.0
	driver.stuck_time = driver.stuck_time + delta if body.linear_velocity.length() < STUCK_SPEED else 0.0
	if driver.roof_time > ROOF_TIME:
		return "on its roof"
	if driver.stuck_time > STUCK_TIME:
		return "stuck"
	return ""

## Lifts the whole car (body, wheels and anything jointed to them) upright to
## the end of the pit furthest from any rival and lets it drop, already
## driving back towards the middle.
func _respawn(driver: Driver) -> void:
	var body := driver.car.body
	var x := _respawn_x(driver)
	var upright := Transform2D(0.0, body.global_transform.get_scale(), 0.0, Vector2(x, driver.floor_y - RESPAWN_DROP_HEIGHT))
	var from_body := body.global_transform.affine_inverse()
	for part in _rigid_parts(driver):
		var moved := upright * from_body * part.global_transform
		PhysicsServer2D.body_set_state(part.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, moved)
		part.global_transform = moved
		part.linear_velocity = Vector2.ZERO
		part.angular_velocity = 0.0
	driver.roof_time = 0.0
	driver.stuck_time = 0.0
	driver.last_hitter = null
	driver.last_hit_time = -INF
	driver.direction = signf((_arena_left + _arena_right) * 0.5 - x)
	driver.retarget_in = RETARGET_TIME.y
	_set_spin(driver, driver.direction)
	respawned.emit(driver)

## The drop-in spot by whichever wall has its nearest rival further away.
func _respawn_x(driver: Driver) -> float:
	var left_x := _arena_left + RESPAWN_WALL_INSET
	var right_x := _arena_right - RESPAWN_WALL_INSET
	var left_gap := INF
	var right_gap := INF
	for other in running():
		if other == driver or not is_instance_valid(other.car.body):
			continue
		var other_x := other.car.body.global_position.x
		left_gap = minf(left_gap, absf(other_x - left_x))
		right_gap = minf(right_gap, absf(other_x - right_x))
	return left_x if left_gap > right_gap else right_x

## Body, wheels and the accessories hung off them, but not the debris of
## broken parts, which lies loose under the car's root.
func _rigid_parts(driver: Driver) -> Array[RigidBody2D]:
	var parts: Array[RigidBody2D] = []
	for part in [driver.car.body] + driver.car.wheels:
		if not is_instance_valid(part):
			continue
		parts.append(part)
		for child in (part as Node).find_children("*", "RigidBody2D", true, false):
			parts.append(child as RigidBody2D)
	return parts

func _knock_out(driver: Driver, reason: String) -> void:
	stop(driver)
	var killer: Driver = null
	if driver.last_hitter != null and elapsed - driver.last_hit_time <= KILL_CREDIT_TIME:
		killer = driver.last_hitter
		killer.kills += 1
	knocked_out.emit(driver, reason, killer)
