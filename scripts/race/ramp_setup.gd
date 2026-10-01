extends Node2D
## Single-car ramp jump: the player's garage car spawns on the flat start,
## rolls down the hill, launches off the kicker and either clears the spike
## pit or drops into it. The car is the same CarAssembler rig with the same
## physics as the drag strip: nothing here pushes, weighs or steers it.
##
## The sibling RaceController is only used for Escape-to-exit: its
## finish_x/max_duration are set far past anything this track reaches.

@export var race_controller_path: NodePath
@export var camera_path: NodePath
@export var spike_sensor_path: NodePath

## On the flat start; CarAssembler stands the car on this y by its lowest point.
const SPAWN_POSITION := Vector2(-200.0, 0.0)
## How long the wreck sits in the spikes before heading back to the map.
const SPIKED_EXIT_DELAY := 3.0

var _player_car: CarAssembler.AssembledCar
var _race_controller: RaceController
var _spiked := false

func _ready() -> void:
	_race_controller = get_node(race_controller_path) as RaceController
	var camera := get_node(camera_path) as CameraFollow
	(get_node(spike_sensor_path) as Area2D).body_entered.connect(_on_spike_sensor_body_entered)

	var cars_container := Node2D.new()
	cars_container.name = "Cars"
	add_child(cars_container)

	var car_data := DebugRace.random_car() if DebugRace.consume() else Inventory.get_selected_car()
	_player_car = CarAssembler.assemble_from_car_data(car_data, cars_container, SPAWN_POSITION)
	if _player_car == null:
		return
	_player_car.root.name = "Player_%s" % car_data.display_name
	_race_controller.register_car(_player_car.root.name, _player_car)
	if camera != null:
		camera.targets = [_player_car.body]
	CarAutosteer.switch_off(_player_car.body)

## CarAssembler bolts a CarAutosteer onto every body so drag racers drift
## between lanes. This track has one lane, so it's switched off, the same way
## single_lane_race_setup.gd does it.
func _on_spike_sensor_body_entered(body: Node2D) -> void:
	if _spiked or _player_car == null:
		return
	if body != _player_car.body and not (body is CarWheel and _player_car.wheels.has(body)):
		return
	_spiked = true
	_hit_spikes.call_deferred()

## Pops every wheel on the spikes and sends the player back to the map.
func _hit_spikes() -> void:
	if is_instance_valid(_player_car.body):
		RaceCarAudio.play(_player_car.root, &"spike_pop", _player_car.body.global_position, -2.0)
	for wheel in _player_car.wheels.duplicate():
		if not is_instance_valid(wheel):
			continue
		var damage := CarPartDamage.of(wheel)
		if damage != null:
			damage.apply_damage(INF)
	get_tree().create_timer(SPIKED_EXIT_DELAY).timeout.connect(_race_controller.exit_race)
