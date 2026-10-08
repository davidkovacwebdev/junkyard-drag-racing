extends Node2D
## The demolition derby: five cars in one walled mud pit, all on the same
## collision layer, so every hit is real physics and real CarPartDamage. Each
## car is driven by a dumb derby brain: pick a rival, drive at it (reversing
## if it's behind, rear first like a real derby driver), and pick again every
## couple of seconds or when about to hit a wall.
##
## A car is out when its body breaks, it lies on its roof, it loses every
## wheel, or it sits still too long. The last car running wins; at the time
## limit the survivor with the most kills does, then the healthiest
## (RaceController.leader_wins_at_end, fed by set_progress with each car's
## remaining durability). A knockout is credited to the last rival that
## touched the car within KILL_CREDIT_TIME.

@export var race_controller_path: NodePath
@export var camera_path: NodePath
@export var track_path: NodePath = ^"Track"

const CAR_COUNT := 5
## Arena floor x's the cars start on, left to right.
const SPAWN_XS: Array[float] = [500.0, 950.0, 1400.0, 1850.0, 2300.0]
## The cars' own layer: they hit each other, the floor and the walls.
const CAR_LAYER := 128
const ARENA_LAYERS := 2 | 64
const RETARGET_TIME := Vector2(1.2, 2.6)
## Turn around this far short of a wall rather than grind against it.
const WALL_TURN_DISTANCE := 260.0
## Lying past this angle for ROOF_TIME seconds counts as on its roof.
const ROOF_ANGLE := 2.0
const ROOF_TIME := 3.0
const STUCK_SPEED := 30.0
const STUCK_TIME := 7.0
## Share of each part's durability it enters the pit with. Head-on hits in
## one line are slow, so at full strength nothing ever breaks.
const DERBY_DURABILITY := 0.3
const KILL_CREDIT_TIME := 5.0
const KILL_CALLOUT_OFFSET := Vector2(0.0, -140.0)

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
	var last_hitter: Driver = null
	var last_hit_time := -INF

var _race_controller: RaceController
var _drivers: Array[Driver] = []
var _driver_of_part: Dictionary = {}
var _elapsed := 0.0
var _signup: RaceSignup = null
var _arena_left := 0.0
var _arena_right := 2800.0

func _ready() -> void:
	_race_controller = get_node_or_null(race_controller_path) as RaceController
	var camera := get_node_or_null(camera_path) as CameraFollow
	var track := get_node_or_null(track_path)
	if track != null:
		_arena_left = (track.get_node("LeftWall") as Node2D).position.x
		_arena_right = (track.get_node("RightWall") as Node2D).position.x
	var cars := Node2D.new()
	cars.name = "Cars"
	add_child(cars)

	var entrants: Array[Dictionary] = []
	if DebugRace.consume():
		for i in CAR_COUNT:
			var car_data := DebugRace.random_car()
			var car_name := "Player_%s" % car_data.display_name if i == 0 else "Car%d_%s" % [i, car_data.display_name]
			entrants.append({"name": car_name, "model": car_data})
	else:
		_signup = RaceSignup.take_pending()
		var player_car := _signup.player_car()
		if player_car != null:
			_signup.player_car_name = "Player_%s" % player_car.display_name
			entrants.append({"name": _signup.player_car_name, "model": player_car})
		for rival in _signup.rival_specs(CAR_COUNT - entrants.size(), RaceProgression.Course.DRAG):
			var car_name := RaceSignup.rival_car_name(entrants.size(), rival)
			_signup.field_car_names.append(car_name)
			entrants.append({"name": car_name, "model": RaceProgression.rival_car_model(rival)})
		_signup.hook_up(_race_controller)

	var spawn_order := range(CAR_COUNT)
	spawn_order.shuffle()
	var camera_targets: Array[Node2D] = []
	for i in entrants.size():
		var car := CarAssembler.assemble_from_car_data(entrants[i]["model"], cars, Vector2(SPAWN_XS[spawn_order[i]], 0.0))
		if car == null:
			continue
		_add_driver(entrants[i]["name"], car)
		camera_targets.append(car.body)
	if camera != null:
		camera.targets = camera_targets

func _add_driver(car_name: String, car: CarAssembler.AssembledCar) -> void:
	car.root.name = car_name
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
	for part in [car.body] + car.wheels:
		_driver_of_part[part] = driver
	for wheel in car.wheels:
		driver.full_spin[wheel] = wheel.target_angular_velocity
	_drivers.append(driver)
	if _race_controller != null:
		_race_controller.register_car(car_name, car)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	for driver in _drivers:
		if not driver.out:
			_record_hits(driver)
	for driver in _drivers:
		if driver.out:
			continue
		var reason := _knockout_reason(driver, delta)
		if not reason.is_empty():
			print("    %s is out: %s" % [driver.car_name, reason])
			_knock_out(driver)
			continue
		_drive(driver, delta)
		if _race_controller != null:
			_race_controller.set_progress(driver.car_name, _health(driver))
	var running := _drivers.filter(func(driver: Driver) -> bool: return not driver.out)
	if running.size() == 1 and _drivers.size() > 1 and _race_controller != null:
		_race_controller.crown(running[0].car_name)
		running[0].out = true

func _record_hits(driver: Driver) -> void:
	for part in [driver.car.body] + driver.car.wheels:
		if not is_instance_valid(part):
			continue
		for other in (part as RigidBody2D).get_colliding_bodies():
			var hitter: Driver = _driver_of_part.get(other)
			if hitter != null and hitter != driver:
				driver.last_hitter = hitter
				driver.last_hit_time = _elapsed

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
	for other in _drivers:
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

func _knock_out(driver: Driver) -> void:
	driver.out = true
	_set_spin(driver, 0.0)
	if _race_controller != null:
		_race_controller.knock_out(driver.car_name)
	Sfx.play(&"knockout_bell", -6.0, 0.03)
	if driver.last_hitter != null and _elapsed - driver.last_hit_time <= KILL_CREDIT_TIME:
		print("    %s gets the kill" % driver.last_hitter.car_name)
		if is_instance_valid(driver.last_hitter.car.body):
			Pickup.spawn_callout(self, driver.last_hitter.car.body.global_position + KILL_CALLOUT_OFFSET, "KILL!")
		if _race_controller != null:
			_race_controller.credit_kill(driver.last_hitter.car_name)
		if driver.last_hitter.car_name.begins_with("Player_"):
			Sfx.play(&"derby_kill", -4.0, 0.03)

## Share of durability left over the body and wheels still on.
func _health(driver: Driver) -> float:
	var total := 0.0
	var parts := 0
	for part in [driver.car.body] + driver.car.wheels:
		parts += 1
		var tracker := CarPartDamage.of(part) if is_instance_valid(part) else null
		if tracker != null and not tracker.is_broken:
			total += tracker.current_durability / tracker.max_durability
	return total / maxi(parts, 1)
