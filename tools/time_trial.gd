class_name TimeTrial
extends Node2D
## Races car specs ({"body", "engine", "wheels"} scene paths) one car per flat
## floor, CARS_PER_BATCH at a time, over the drag strip's distance. Each spec
## gets "time" (RaceProgression.DID_NOT_FINISH if it never got there), "distance"
## (how far it got) and "wrecked" (whether its body broke). Used by the roster
## builder and the part benchmark.
##
## Cars are dealt out over one headless worker process per CPU core. Physics
## runs aren't bit-identical anyway (Godot's 2D solver and some parts' random
## wobble), so which cars share a worker doesn't matter.

signal finished(results: Array[Dictionary])

const CARS_PER_BATCH := 16
const SPAWN_X := 150.0
## Same run as the drag strip: start to finish line on race_drag_strip.tscn.
const FINISH_X := 5400.0
const TIME_LIMIT := 90.0
const FLOOR_SPACING := 1500.0
const WORKER_SCENE := "res://tools/time_trial_worker.tscn"
const WORKER_DIR := "user://time_trial_workers"
const WORKER_POLL_MSEC := 100

var _pending: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _total := 0
var _batch_specs: Array[Dictionary] = []
var _batch_cars: Array[CarAssembler.AssembledCar] = []
var _batch_root: Node2D = null
var _batch_elapsed := 0.0
var _worker_specs: Array[Array] = []
var _worker_pids: Array[int] = []

func run(specs: Array[Dictionary]) -> void:
	var worker_count := mini(specs.size(), OS.get_processor_count())
	if worker_count <= 1:
		run_in_this_process(specs)
		return
	_results = specs.duplicate()
	_worker_specs.clear()
	_worker_pids.clear()
	for worker in worker_count:
		_worker_specs.append([])
	for i in specs.size():
		_worker_specs[i % worker_count].append(specs[i])
	DirAccess.make_dir_recursive_absolute(WORKER_DIR)
	for worker in worker_count:
		_worker_pids.append(_spawn_worker(worker, _worker_specs[worker]))

func run_in_this_process(specs: Array[Dictionary]) -> void:
	_pending = specs.duplicate()
	_results.clear()
	_total = specs.size()
	_start_batch.call_deferred()

func _process(_delta: float) -> void:
	if _worker_pids.is_empty():
		return
	for pid in _worker_pids:
		if OS.is_process_running(pid):
			OS.delay_msec(WORKER_POLL_MSEC)
			return
	_worker_pids.clear()
	_collect_worker_results()

func _spawn_worker(worker: int, specs: Array) -> int:
	var car_specs: Array[Dictionary] = []
	for spec in specs:
		car_specs.append({"body": spec["body"], "engine": spec["engine"], "wheels": spec["wheels"]})
	var file := FileAccess.open(worker_specs_path(worker), FileAccess.WRITE)
	file.store_string(JSON.stringify(car_specs))
	file.close()
	var arguments := PackedStringArray([
		"--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		WORKER_SCENE, "--", "--no-save", "--worker=%d" % worker])
	# Godot's idle helper threads spin on whatever cores they can reach, so
	# unpinned workers burn each other's CPU. Pinned, each gets a core to itself.
	if OS.get_name() == "Linux":
		arguments = PackedStringArray(["-c", str(worker), OS.get_executable_path()]) + arguments
		return OS.create_process("taskset", arguments)
	return OS.create_process(OS.get_executable_path(), arguments)

func _collect_worker_results() -> void:
	for worker in _worker_specs.size():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(worker_results_path(worker)))
		var specs: Array = _worker_specs[worker]
		if not parsed is Array or (parsed as Array).size() != specs.size():
			push_error("TimeTrial: worker %d returned no results" % worker)
			get_tree().quit(1)
			return
		for i in specs.size():
			var spec: Dictionary = specs[i]
			var result: Dictionary = parsed[i]
			spec["time"] = float(result["time"])
			spec["distance"] = float(result["distance"])
			spec["wrecked"] = bool(result["wrecked"])
		DirAccess.remove_absolute(worker_specs_path(worker))
		DirAccess.remove_absolute(worker_results_path(worker))
	finished.emit(_results)

static func worker_specs_path(worker: int) -> String:
	return "%s/specs_%d.json" % [WORKER_DIR, worker]

static func worker_results_path(worker: int) -> String:
	return "%s/results_%d.json" % [WORKER_DIR, worker]

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
			spec["wrecked"] = true
			car.root.queue_free()
		elif car.body.global_position.x >= FINISH_X:
			spec["time"] = snappedf(_batch_elapsed, 0.01)
			spec["distance"] = FINISH_X - SPAWN_X
			# Done cars would otherwise keep simulating until the batch's
			# slowest car gives up.
			car.root.queue_free()
		else:
			spec["distance"] = snappedf(car.body.global_position.x - SPAWN_X, 1.0)
			all_done = false
	if all_done or _batch_elapsed >= TIME_LIMIT:
		_finish_batch()

func _start_batch() -> void:
	_batch_root = Node2D.new()
	add_child(_batch_root)
	_batch_elapsed = 0.0
	_batch_specs.clear()
	_batch_cars.clear()
	for i in mini(CARS_PER_BATCH, _pending.size()):
		var spec: Dictionary = _pending.pop_front()
		spec["wrecked"] = false
		spec["distance"] = 0.0
		var floor_y := i * FLOOR_SPACING
		_add_floor(floor_y)
		var wheel_scenes: Array[PackedScene] = []
		for wheel_path in spec["wheels"]:
			wheel_scenes.append(load(wheel_path))
		var car := CarAssembler.assemble(load(spec["body"]), wheel_scenes, load(spec["engine"]),
				_batch_root, Vector2(SPAWN_X, floor_y))
		_remove_engine_sound(car)
		_batch_specs.append(spec)
		_batch_cars.append(car)

func _finish_batch() -> void:
	for spec in _batch_specs:
		if not spec.has("time"):
			spec["time"] = RaceProgression.DID_NOT_FINISH
		_results.append(spec)
	_batch_root.queue_free()
	_batch_root = null
	print("time trial: %d / %d" % [_results.size(), _total])
	if _pending.is_empty():
		finished.emit(_results)
	else:
		_start_batch.call_deferred()

## Nobody hears a time trial, and synthesizing engine sound was most of each
## frame's cost. It only reads the wheels, so the race comes out the same.
static func _remove_engine_sound(car: CarAssembler.AssembledCar) -> void:
	for child in car.body.get_children():
		if child is EngineSound:
			child.free()

func _add_floor(floor_y: float) -> void:
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8000.0, 60.0)
	var shape := CollisionShape2D.new()
	shape.shape = rectangle
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(3400.0, floor_y + 30.0)
	floor_body.add_child(shape)
	_batch_root.add_child(floor_body)
