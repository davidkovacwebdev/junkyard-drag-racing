extends Node2D
## Test harness: randomly assembles CAR_COUNT cars (random body, independent
## random front/back wheels, random engine) and registers them with the
## sibling RaceController. This is throwaway test scaffolding, not the
## Phase 4 garage/opponent-generation system — it just proves random part
## combos (including mismatched front/back wheels) all drive correctly.

@export var race_controller_path: NodePath
@export var camera_path: NodePath

const CAR_COUNT := 6
const LANE_HEIGHT := 230.0
const SPAWN_X := 150.0
const SPAWN_HEIGHT_ABOVE_LANE := 15.0

var body_scenes: Array[PackedScene] = [
	preload("res://scenes/parts/bodies/body_plank.tscn"),
	preload("res://scenes/parts/bodies/body_wrecked_car.tscn"),
	preload("res://scenes/parts/bodies/body_fridge.tscn"),
	preload("res://scenes/parts/bodies/body_sofa.tscn"),
	preload("res://scenes/parts/bodies/body_boat.tscn"),
]

var wheel_scenes: Array[PackedScene] = [
	# wheel_bicycle.tscn removed on purpose — it's the one round/easy wheel,
	# and the point right now is maximum chaos from the wild shapes.
	preload("res://scenes/parts/wheels/wheel_square.tscn"),
	preload("res://scenes/parts/wheels/wheel_triangle.tscn"),
	preload("res://scenes/parts/wheels/wheel_toilet.tscn"),
	preload("res://scenes/parts/wheels/wheel_tv.tscn"),
]

var engine_scenes: Array[PackedScene] = [
	preload("res://scenes/parts/engines/engine_v6.tscn"),
	preload("res://scenes/parts/engines/engine_boiler.tscn"),
	preload("res://scenes/parts/engines/engine_propeller.tscn"),
	preload("res://scenes/parts/engines/engine_sail.tscn"),
	preload("res://scenes/parts/engines/engine_jet.tscn"),
]

func _ready() -> void:
	var race_controller := get_node(race_controller_path) as RaceController
	var camera := get_node(camera_path) as CameraFollow

	var cars_container := Node2D.new()
	cars_container.name = "Cars"
	add_child(cars_container)

	var camera_targets: Array[Node2D] = []

	# The player's own garage car races in the top lane, so whatever they
	# assembled in the garage is what they drive here too.
	var lane := 0
	var player_car := Inventory.get_selected_car()
	if player_car != null and player_car.body != null and not player_car.body.scene_path.is_empty():
		var car := _assemble_player_car(player_car, cars_container, lane)
		var car_name := "Player_%s" % player_car.display_name
		car.root.name = car_name
		race_controller.register_car(car_name, car)
		camera_targets.append(car.body)
		lane += 1

	for i in range(lane, CAR_COUNT):
		var body_scene: PackedScene = body_scenes[randi() % body_scenes.size()]
		var wheel_front: PackedScene = wheel_scenes[randi() % wheel_scenes.size()]
		var wheel_back: PackedScene = wheel_scenes[randi() % wheel_scenes.size()]
		var engine_scene: PackedScene = engine_scenes[randi() % engine_scenes.size()]

		var lane_top := i * LANE_HEIGHT
		var spawn_position := Vector2(SPAWN_X, lane_top - SPAWN_HEIGHT_ABOVE_LANE)
		var car := CarAssembler.assemble(body_scene, [wheel_front, wheel_back], engine_scene, cars_container, spawn_position)

		var car_name := "Car%d_%s_%s+%s_%s" % [
			i,
			body_scene.resource_path.get_file().trim_suffix(".tscn"),
			wheel_front.resource_path.get_file().trim_suffix(".tscn"),
			wheel_back.resource_path.get_file().trim_suffix(".tscn"),
			engine_scene.resource_path.get_file().trim_suffix(".tscn"),
		]
		car.root.name = car_name
		race_controller.register_car(car_name, car)
		camera_targets.append(car.body)

	if camera != null:
		camera.targets = camera_targets

## Builds the player's selected garage car into the race. Reuses the exact
## part scene paths stored on the CarModelData, so the racing rig is the
## same body/wheels/engine the garage preview (and world player) show.
func _assemble_player_car(car_data: CarModelData, parent: Node2D, lane: int) -> CarAssembler.AssembledCar:
	var body_scene: PackedScene = load(car_data.body.scene_path)
	var wheel_scenes: Array[PackedScene] = []
	for wheel in car_data.wheels:
		if wheel != null and not wheel.scene_path.is_empty():
			wheel_scenes.append(load(wheel.scene_path))
	var engine_scene: PackedScene = null
	if car_data.engine != null and not car_data.engine.scene_path.is_empty():
		engine_scene = load(car_data.engine.scene_path)
	var spawn_position := Vector2(SPAWN_X, lane * LANE_HEIGHT - SPAWN_HEIGHT_ABOVE_LANE)
	return CarAssembler.assemble(body_scene, wheel_scenes, engine_scene, parent, spawn_position)
