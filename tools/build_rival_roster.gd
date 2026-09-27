extends Node2D
## Bakes data/rival_roster.json: random junk cars built from the PartDatabase
## catalog, each raced alone on a flat strip and timed. RaceProgression picks
## drag strip opponents out of it by finish time, so difficulty is based on how
## fast a car actually is rather than on its parts' star ratings. Rerun after
## adding or retuning parts:
##   godot --headless --fixed-fps 60 res://tools/build_rival_roster.tscn

const ROSTER_SIZE := 240
const CARS_PER_BATCH := 8
const SPAWN_X := 150.0
## Same run as the drag strip: start to finish line on race_drag_strip.tscn.
const FINISH_X := 5400.0
const TIME_LIMIT := 90.0
const FLOOR_SPACING := 1500.0
const RNG_SEED := 1337

var _rng := RandomNumberGenerator.new()
var _roster: Array[Dictionary] = []
var _batch_specs: Array[Dictionary] = []
var _batch_cars: Array[CarAssembler.AssembledCar] = []
var _batch_root: Node2D = null
var _batch_elapsed := 0.0

func _ready() -> void:
	_rng.seed = RNG_SEED
	_start_batch.call_deferred()

func _physics_process(delta: float) -> void:
	if _batch_root == null:
		return
	_batch_elapsed += delta
	var all_done := true
	for i in _batch_cars.size():
		var spec := _batch_specs[i]
		if spec.has("time"):
			continue
		var car := _batch_cars[i]
		if not is_instance_valid(car.body):
			spec["time"] = RaceProgression.DID_NOT_FINISH
		elif car.body.global_position.x >= FINISH_X:
			spec["time"] = snappedf(_batch_elapsed, 0.01)
		else:
			all_done = false
	if all_done or _batch_elapsed >= TIME_LIMIT:
		_finish_batch()

func _start_batch() -> void:
	_batch_root = Node2D.new()
	add_child(_batch_root)
	_batch_elapsed = 0.0
	_batch_specs.clear()
	_batch_cars.clear()
	var count := mini(CARS_PER_BATCH, ROSTER_SIZE - _roster.size())
	for i in count:
		var spec := _random_spec()
		var floor_y := i * FLOOR_SPACING
		_add_floor(floor_y)
		var wheel_scenes: Array[PackedScene] = []
		for wheel_path in spec["wheels"]:
			wheel_scenes.append(load(wheel_path))
		var car := CarAssembler.assemble(load(spec["body"]), wheel_scenes, load(spec["engine"]),
				_batch_root, Vector2(SPAWN_X, floor_y - 15.0))
		_batch_specs.append(spec)
		_batch_cars.append(car)

func _finish_batch() -> void:
	for spec in _batch_specs:
		if not spec.has("time"):
			spec["time"] = RaceProgression.DID_NOT_FINISH
		_roster.append(spec)
	_batch_root.queue_free()
	_batch_root = null
	print("rival roster: %d / %d" % [_roster.size(), ROSTER_SIZE])
	if _roster.size() < ROSTER_SIZE:
		_start_batch.call_deferred()
	else:
		_save()

func _random_spec() -> Dictionary:
	var body: BodyPartData = PartDatabase.bodies[_rng.randi() % PartDatabase.bodies.size()]
	var engine: EnginePartData = PartDatabase.engines[_rng.randi() % PartDatabase.engines.size()]
	var wheel: WheelPartData = PartDatabase.wheels[_rng.randi() % PartDatabase.wheels.size()]
	var wheels: Array[String] = []
	for i in PartDatabase.wheel_mount_count(body):
		wheels.append(wheel.scene_path)
	return {"body": body.scene_path, "engine": engine.scene_path, "wheels": wheels}

func _add_floor(floor_y: float) -> void:
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8000.0, 60.0)
	var shape := CollisionShape2D.new()
	shape.shape = rectangle
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(3400.0, floor_y + 30.0)
	floor_body.add_child(shape)
	_batch_root.add_child(floor_body)

func _save() -> void:
	_roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"]))
	var file := FileAccess.open(RaceProgression.ROSTER_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_roster, "\t"))
	file.close()
	print("rival roster: wrote %s" % RaceProgression.ROSTER_PATH)
	get_tree().quit()
