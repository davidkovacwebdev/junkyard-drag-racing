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
##
## On top of that real per-lane physics, every car also gets a purely
## cosmetic up/down wobble (see WobbleState below) — the actual physics
## body never leaves its own lane, only its *rendered* visuals shift, so
## there's no risk of reintroducing the instability a real cross-lane
## force caused earlier. "Touching" is a simulated check (x proximity +
## each car's real lane position plus its current cosmetic offset), not a
## real collision — when it fires, it spawns a spark burst and nudges both
## cars' actual velocity down a little, so it reads as a real sideswipe
## without the physics ever leaving solid, single-lane ground.

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

## --- Cosmetic up/down wobble + simulated cross-lane touches ------------------

const WOBBLE_AMPLITUDE := 70.0
const WOBBLE_FREQUENCY := 1.2
## How close two cars' real x, and their real-lane-y plus current cosmetic
## offset, need to be to count as a simulated touch.
const TOUCH_X_THRESHOLD := 180.0
const TOUCH_Y_THRESHOLD := 90.0
## Multiplies both cars' linear_velocity on a touch — real wheel friction
## builds it back up again over the next moment, so this reads as a
## sideswipe slowing them down rather than a hard stop.
const TOUCH_SLOWDOWN := 0.85
## Per-car cooldown so one overlap doesn't spark/slow every single frame
## for as long as two cars happen to stay close.
const TOUCH_COOLDOWN := 1.0

## Everything one car's wobble needs. The physics body/wheels never move
## from this — only body_wrapper/wheel_wrappers (plain, non-collision
## Node2D holding just the Polygon2D visuals) get their position nudged,
## so the wobble is guaranteed cosmetic no matter what.
class WobbleState:
	var car: CarAssembler.AssembledCar
	var noise: FastNoiseLite
	var time: float = 0.0
	var offset: float = 0.0
	var body_wrapper: Node2D
	var wheel_wrappers: Array[Node2D] = []
	var touch_cooldown: float = 0.0

var _wobble_states: Array[WobbleState] = []

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
		_wobble_states.append(_setup_wobble(car))
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
		_wobble_states.append(_setup_wobble(car))

	if camera != null:
		camera.targets = camera_targets

func _physics_process(delta: float) -> void:
	for state in _wobble_states:
		if not is_instance_valid(state.car.body):
			continue
		state.time += delta * WOBBLE_FREQUENCY
		state.offset = state.noise.get_noise_1d(state.time) * WOBBLE_AMPLITUDE
		if is_instance_valid(state.body_wrapper):
			state.body_wrapper.position.y = state.offset
		for wrapper in state.wheel_wrappers:
			if is_instance_valid(wrapper):
				wrapper.position.y = state.offset
		state.touch_cooldown = maxf(state.touch_cooldown - delta, 0.0)

	for i in _wobble_states.size():
		var a := _wobble_states[i]
		if not is_instance_valid(a.car.body) or a.touch_cooldown > 0.0:
			continue
		for j in range(i + 1, _wobble_states.size()):
			var b := _wobble_states[j]
			if not is_instance_valid(b.car.body) or b.touch_cooldown > 0.0:
				continue
			if _is_touching(a, b):
				_on_touch(a, b)

## Simulated contact: real x position (actual physics), real lane y plus
## each car's current cosmetic wobble offset — not a real collision query.
func _is_touching(a: WobbleState, b: WobbleState) -> bool:
	var pos_a: Vector2 = a.car.body.global_position
	var pos_b: Vector2 = b.car.body.global_position
	var dx := absf(pos_a.x - pos_b.x)
	if dx > TOUCH_X_THRESHOLD:
		return false
	var effective_y_a := pos_a.y + a.offset
	var effective_y_b := pos_b.y + b.offset
	return absf(effective_y_a - effective_y_b) <= TOUCH_Y_THRESHOLD

func _on_touch(a: WobbleState, b: WobbleState) -> void:
	a.touch_cooldown = TOUCH_COOLDOWN
	b.touch_cooldown = TOUCH_COOLDOWN
	a.car.body.linear_velocity *= TOUCH_SLOWDOWN
	b.car.body.linear_velocity *= TOUCH_SLOWDOWN
	var midpoint := (a.car.body.global_position + b.car.body.global_position) / 2.0
	_spawn_sparks(midpoint)

func _spawn_sparks(spark_position: Vector2) -> void:
	var particles := CPUParticles2D.new()
	add_child(particles)
	particles.global_position = spark_position
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 240.0
	particles.gravity = Vector2(0.0, 500.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.8, 0.25, 1.0)
	particles.emitting = true
	var cleanup := get_tree().create_timer(particles.lifetime + 0.2)
	cleanup.timeout.connect(particles.queue_free)

## Builds this car's WobbleState: a plain Node2D wrapper under the body and
## under each wheel, holding just their Polygon2D visuals (CollisionPolygon2D
## and everything else stays a direct child, untouched, so collision is
## exactly as before) — moving the wrapper only ever moves what's drawn.
func _setup_wobble(car: CarAssembler.AssembledCar) -> WobbleState:
	var state := WobbleState.new()
	state.car = car
	state.noise = FastNoiseLite.new()
	state.noise.seed = randi()
	state.noise.frequency = 1.0 # see car sway history: this is time input, not spatial.
	state.body_wrapper = _wrap_visuals(car.body, car.engine)
	for wheel in car.wheels:
		state.wheel_wrappers.append(_wrap_visuals(wheel))
	return state

func _wrap_visuals(physics_body: Node2D, extra_child: Node2D = null) -> Node2D:
	var wrapper := Node2D.new()
	wrapper.name = "VisualWobble"
	physics_body.add_child(wrapper)
	for child in physics_body.get_children().duplicate():
		if child == wrapper:
			continue
		if child is Polygon2D or child == extra_child:
			child.reparent(wrapper, false)
	return wrapper

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
