class_name DerbySetup
extends Node2D
## The demolition derby: five cars in one walled mud pit, fought out by a
## DerbyBout. The last car running wins; at the time limit the survivor with
## the most kills does, then the healthiest (RaceController.leader_wins_at_end,
## fed by set_progress with each car's remaining durability).

@export var race_controller_path: NodePath
@export var camera_path: NodePath
@export var track_path: NodePath = ^"Track"

const CAR_COUNT := 5
## Arena floor x's the cars start on, left to right.
const SPAWN_XS: Array[float] = [500.0, 950.0, 1400.0, 1850.0, 2300.0]
const KILL_CALLOUT_OFFSET := Vector2(0.0, -140.0)

var _race_controller: RaceController
var _bout: DerbyBout
var _signup: RaceSignup = null

func _ready() -> void:
	_race_controller = get_node_or_null(race_controller_path) as RaceController
	var camera := get_node_or_null(camera_path) as CameraFollow
	var track := get_node_or_null(track_path)
	_bout = DerbyBout.new((track.get_node("LeftWall") as Node2D).global_position.x,
			(track.get_node("RightWall") as Node2D).global_position.x)
	_bout.knocked_out.connect(_on_knocked_out)
	_bout.last_one_standing.connect(_on_last_one_standing)
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
		for rival in _signup.rival_specs(CAR_COUNT - entrants.size(), RaceProgression.Course.DERBY):
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
	_bout.add_car(car_name, car)
	if _race_controller != null:
		_race_controller.register_car(car_name, car)

func _physics_process(delta: float) -> void:
	_bout.step(delta)
	if _race_controller == null:
		return
	for driver in _bout.running():
		_race_controller.set_progress(driver.car_name, DerbyBout.health(driver))

func _on_knocked_out(driver: DerbyBout.Driver, reason: String, killer: DerbyBout.Driver) -> void:
	print("    %s is out: %s" % [driver.car_name, reason])
	if _race_controller != null:
		_race_controller.knock_out(driver.car_name)
	Sfx.play(&"knockout_bell", -6.0, 0.03)
	if killer == null:
		return
	print("    %s gets the kill" % killer.car_name)
	if is_instance_valid(killer.car.body):
		Pickup.spawn_callout(self, killer.car.body.global_position + KILL_CALLOUT_OFFSET, "KILL!")
	if _race_controller != null:
		_race_controller.credit_kill(killer.car_name)
	if killer.car_name.begins_with("Player_"):
		Sfx.play(&"derby_kill", -4.0, 0.03)

func _on_last_one_standing(driver: DerbyBout.Driver) -> void:
	if _race_controller != null:
		_race_controller.crown(driver.car_name)
	driver.out = true
