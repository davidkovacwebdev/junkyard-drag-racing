extends Node2D
## Drag strip test harness: randomly assembles CAR_COUNT cars (random body,
## independent random front/back wheels, random engine) and registers them
## with the sibling RaceController. Same CarAssembler wheel-physics rig as
## random_race_setup.gd (real gravity, rolling wheels, CarPartDamage/
## PartShatter breakage) — the only difference is LANE_HEIGHT: lanes here
## sit closer together than the original 230px (200 vs 230), close enough
## that a tall body/wheel combo can physically reach into the lane above or
## below it. Whether two cars ever actually touch depends on how tall their
## specific combo turned out — real contact resolved by real collision
## shapes, not a scripted rule.
##
## random_race_setup.gd is left alone on purpose: it still drives the ramp
## test harness (race_ramp_test.tscn), which wants its cars kept apart.

@export var race_controller_path: NodePath
@export var camera_path: NodePath

const CAR_COUNT := 5
## The real constraint here isn't "tight" so much as "wider than the
## floor's own 60px thickness by more than any wheel's own diameter"
## (wheels run roughly 70-90px across — see e.g. wheel_square.tscn's
## collision polygon). LANE_HEIGHT - 60 is the actual air gap between
## adjacent lanes; if that gap is smaller than a resting wheel, the wheel
## touches the lane above it too, and Godot's contact resolution gets
## confused between the two surfaces — anywhere from a dead freeze to
## instant, spawn-time part destruction. Confirmed directly at 110 and
## 150 (gaps of 50 and 90 — both too small); 200 (gap 140) is the first
## value with comfortable clearance over the largest wheel.
const LANE_HEIGHT := 200.0
const SPAWN_X := 150.0
const SPAWN_HEIGHT_ABOVE_LANE := 15.0
## Wider than any body's own width (up to ~280px for body_plank) so five
## cars dropped at once don't land on top of each other before any of
## them reaches its own lane — same reasoning, different axis.
const SPAWN_STAGGER_X := 300.0

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

		var spawn_position := _spawn_position(i)
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

## Spawns `SPAWN_HEIGHT_ABOVE_LANE` above the lane's own resting surface,
## same as the original per-lane setup, so the car still drops onto it
## under real gravity — staggered along x by SPAWN_STAGGER_X too, so all
## five don't drop through the same column at once.
func _spawn_position(lane: int) -> Vector2:
	return Vector2(SPAWN_X + lane * SPAWN_STAGGER_X, lane * LANE_HEIGHT - SPAWN_HEIGHT_ABOVE_LANE)

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
	return CarAssembler.assemble(body_scene, wheel_scenes, engine_scene, parent, _spawn_position(lane))
