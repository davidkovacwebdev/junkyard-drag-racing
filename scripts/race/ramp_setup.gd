extends Node2D
## Single-car ramp jump: the player's garage car spawns on a flat start,
## rolls downhill under real gravity — same rig, same always-on engine
## every race car uses, nothing here is player-driven — launches off a
## ramp, and (hopefully) clears the gap to land on the far side.
##
## Reuses CarAssembler.assemble_from_car_data() (see car_assembler.gd) for
## the actual car-building — the same call random_race_setup.gd makes for
## the player's own lane — and the sibling RaceController purely for its
## Escape-to-exit handling. finish_x/max_duration are set far beyond
## anything this track can produce so RaceController's finish-line/win
## logic never fires; there's nothing to race against here, just a jump.

@export var race_controller_path: NodePath
@export var camera_path: NodePath

## On the flat start, just above the ground so the car settles onto it
## under gravity rather than spawning already interpenetrating the floor.
const SPAWN_POSITION := Vector2(-200.0, -15.0)

## A kick down the hill, held for as long as the car is actually on the
## Start/Downhill slope rather than a fixed timer. This is NOT
## CarBody.boost_force (the finish-line mechanic — a flat push on the
## chassis): a wheel forces its own rotation to target_angular_velocity
## every physics step regardless of what's pushing the chassis (see
## CarWheel), so on a weak engine (the worst tier-1 parts spin the wheels
## at just 0.8 rad/s) that slow-spinning wheel just acts as a drag brake
## against almost any body force — tried up to 160000 (matching
## RaceController's own finish slam) and most of it either got eaten by
## that resistance or, past some threshold, overwhelmed it entirely into
## an unrecoverable runaway spin that shattered the car in under 2
## seconds. Boosting through the SAME mechanism the wheel actually obeys
## — its own target speed — sidesteps the fight completely and gives a
## real, bounded launch.
##
## A fixed-duration timer (the original approach) isn't enough on its
## own: it's tuned to get the car off a dead stop, and on a hill this
## long the timer's well expired by the time the car has actually
## reached and descended the slope, so the wheel governor drops back to
## the weak baseline speed partway down — and since the wheel's forced
## rotation is the car's hard speed ceiling (ground friction won't let
## the chassis outrun what the wheel's spin implies, however hard
## gravity's pulling), the rest of the hill barely does anything. Holding
## the boost for the whole Start+Downhill stretch, released only once the
## car reaches the flat Runway, is what actually lets a real downhill
## payoff show through.
##
## Comparable to the strongest engine in the catalog (the jet's 8.0 rad/s)
## rather than something wildly beyond it — tried 25 first and the sudden
## torque snapped a fragile tier-1 wheel clean off in under a second.
const BOOST_ANGULAR_VELOCITY := 10.0
## How fast the wheel's spin ramps up to that boosted target — a bit
## brisker than CarWheel's own default motor_accel (20.0) so the kick
## lands quickly, but not so sharp it shocks a fragile wheel apart.
const BOOST_MOTOR_ACCEL := 30.0
## World x where the Downhill segment ends and the flat Runway begins
## (Downhill node position.x 500 + its local run of 2500) — past this,
## gravity's no longer doing any work, so the boost releases here.
const DOWNHILL_END_X := 3000.0

var _player_car: CarAssembler.AssembledCar
var _original_speeds: Array[float] = []
var _original_accels: Array[float] = []
var _boost_released := false

func _ready() -> void:
	# Debug aid while tuning this track's geometry: draws every collision
	## shape (floor slabs, the downhill/ramp wedges, the end wall) with the
	# engine's normal translucent-green overlay, same as toggling Debug >
	# Visible Collision Shapes in the editor, but scoped to just this scene
	# instead of every run. Remove once the track's settled.
	get_tree().debug_collisions_hint = true

	var race_controller := get_node(race_controller_path) as RaceController
	var camera := get_node(camera_path) as CameraFollow

	var cars_container := Node2D.new()
	cars_container.name = "Cars"
	add_child(cars_container)

	var player_car := Inventory.get_selected_car()
	var car := CarAssembler.assemble_from_car_data(player_car, cars_container, SPAWN_POSITION)
	if car == null:
		return
	car.root.name = "Player_%s" % player_car.display_name
	race_controller.register_car(car.root.name, car)
	if camera != null:
		camera.targets = [car.body]
	_neutralize_autosteer(car)

	_player_car = car
	for wheel in car.wheels:
		_original_speeds.append(wheel.target_angular_velocity)
		_original_accels.append(wheel.motor_accel)
		wheel.target_angular_velocity = BOOST_ANGULAR_VELOCITY
		wheel.motor_accel = BOOST_MOTOR_ACCEL

func _physics_process(_delta: float) -> void:
	if _boost_released or _player_car == null or not is_instance_valid(_player_car.body):
		return
	if _player_car.body.global_position.x < DOWNHILL_END_X:
		return
	_boost_released = true
	for i in _player_car.wheels.size():
		if is_instance_valid(_player_car.wheels[i]):
			_player_car.wheels[i].target_angular_velocity = _original_speeds[i]
			_player_car.wheels[i].motor_accel = _original_accels[i]

## CarAssembler bolts a CarAutosteer onto every car body — a real vertical
## force (fast noise, hundreds of newtons) that makes cars wander up/down
## a bit, meant for the multi-lane drag strip where that's what lets cars
## drift into a neighboring lane. This is a single-lane jump: any up/down
## wander is just unwanted noise fighting a clean run down the hill and a
## predictable launch arc, so it's switched off — same pattern
## single_lane_race_setup.gd uses to neutralize it for its own reasons.
func _neutralize_autosteer(car: CarAssembler.AssembledCar) -> void:
	if not is_instance_valid(car.body):
		return
	for child in car.body.get_children():
		if child is CarAutosteer:
			child.set_physics_process(false)
