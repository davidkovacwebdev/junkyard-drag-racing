class_name DebugRace
## A race outside the campaign: nothing is recorded or paid out. Two ways in:
## T at a race entrance on the map (every car a fully random pick from the part
## catalog, for testing parts and tracks), and the Ctrl+G random race popup
## (RandomRacePopup), which can also pick a tier's roster cars and put the
## player's garage car, or a roster car they picked, in the first lane.
##
## A fresh scene can't take parameters, so the request is made right before
## switching and the race setup consumes it in its _ready().
##
## A request with a seed seeds the global RNG the moment the race scene enters
## the tree, before any of its nodes roll anything, so the same seed builds the
## same race: rivals, random cars, names, lanes, hazards.

## Chance of a fully random car wearing something in each accessory spot.
const RANDOM_ACCESSORY_CHANCE := 0.3

static var _requested := false
## 0 builds every car from random parts; 1-4 picks that tier's roster cars.
static var _tier := 0
## Raced in the first lane when set; otherwise every lane is filled the same way.
static var _player_car: CarModelData = null
static var _seed_on_scene_entry := Callable()

## `race_seed` < 0 leaves the race unseeded.
static func request(tier := 0, player_car: CarModelData = null, race_seed := -1) -> void:
	_requested = true
	_tier = tier
	_player_car = player_car
	var tree := Engine.get_main_loop() as SceneTree
	if _seed_on_scene_entry.is_valid() and tree.node_added.is_connected(_seed_on_scene_entry):
		tree.node_added.disconnect(_seed_on_scene_entry)
	if race_seed < 0:
		return
	_seed_on_scene_entry = func(node: Node) -> void:
		if node.get_parent() != tree.root or node.scene_file_path.is_empty():
			return
		tree.node_added.disconnect(_seed_on_scene_entry)
		seed(race_seed)
	tree.node_added.connect(_seed_on_scene_entry)

## True once for the race the request was made for, then false again.
static func consume() -> bool:
	var was_requested := _requested
	_requested = false
	return was_requested

## The cars for `count` lanes, first lane first.
static func field(count: int, course: RaceProgression.Course) -> Array[CarModelData]:
	var cars: Array[CarModelData] = []
	if _player_car != null:
		cars.append(_player_car)
	if _tier > 0:
		for rival in RaceProgression.pick_rivals_for_tier(count - cars.size(), _tier, course):
			cars.append(RaceProgression.rival_car_model(rival))
	while cars.size() < count:
		cars.append(random_car())
	return cars

## A random body with a random engine, an independently random wheel on every
## mount, and maybe an extra in each spot.
static func random_car() -> CarModelData:
	var car := CarModelData.new()
	car.body = PartDatabase.bodies.pick_random().duplicate()
	car.engine = PartDatabase.engines.pick_random().duplicate()
	car.wheels = []
	for i in PartDatabase.wheel_mount_count(car.body):
		car.wheels.append(PartDatabase.wheels.pick_random().duplicate())
	for spot in AccessoryPartData.Spot.values():
		if randf() >= RANDOM_ACCESSORY_CHANCE:
			continue
		var options := PartDatabase.accessories.filter(func(accessory: AccessoryPartData) -> bool:
			return accessory.spot == spot)
		if not options.is_empty():
			car.set_accessory(options.pick_random().duplicate())
	return car
