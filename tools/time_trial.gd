class_name TimeTrial
extends Node2D
## Races car specs ({"body", "engine", "wheels", "accessories"} scene paths,
## accessories optional) one car per flat floor, CARS_PER_BATCH at a time,
## over the drag strip's distance. Each spec gets "time"
## (RaceProgression.DID_NOT_FINISH if it never got there), "distance" (how far
## it got) and "wrecked" (whether its body broke). Used by the roster builder
## and the part benchmark.
##
## With `on_hill` set, each floor is the hill climb's slope instead, run to
## its summit finish, and "distance" is the furthest the car got.
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
## race_hill_climb.tscn's finish line and time limit.
const HILL_FINISH_X := 3550.0
const HILL_TIME_LIMIT := 60.0
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
var on_hill := false
## What the progress bar calls this run.
var progress_label := "time trial"
## Set in a worker process: where it reports how many cars it has finished.
var progress_path := ""
var _progress: ToolProgress
var _progress_paths := PackedStringArray()
var _hill_profile := HillClimbTrack.new()

func _exit_tree() -> void:
	_hill_profile.free()

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
	_progress_paths.clear()
	for worker in worker_count:
		_progress_paths.append(worker_progress_path(worker))
		ToolProgress.write_worker_file(worker_progress_path(worker), 0)
	_progress = ToolProgress.new(progress_label, specs.size(), "cars",
			"starting %d workers, first cars in soon" % worker_count)
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
	_progress.update_from_files(_progress_paths)
	for pid in _worker_pids:
		if OS.is_process_running(pid):
			OS.delay_msec(WORKER_POLL_MSEC)
			return
	_worker_pids.clear()
	_progress.finish()
	_collect_worker_results()

func _spawn_worker(worker: int, specs: Array) -> int:
	var car_specs: Array[Dictionary] = []
	for spec in specs:
		car_specs.append({"body": spec["body"], "engine": spec["engine"], "wheels": spec["wheels"],
				"accessories": spec.get("accessories", [])})
	var file := FileAccess.open(worker_specs_path(worker), FileAccess.WRITE)
	file.store_string(JSON.stringify(car_specs))
	file.close()
	var arguments := PackedStringArray([
		"--headless", "--quiet", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		WORKER_SCENE, "--", "--no-save", "--worker=%d" % worker])
	if on_hill:
		arguments.append("--hill")
	var executable := OS.get_executable_path()
	# Godot's idle helper threads spin on whatever cores they can reach, so
	# unpinned workers burn each other's CPU. Pinned, each gets a core to itself.
	if OS.get_name() == "Linux":
		arguments = PackedStringArray(["-c", str(worker), executable]) + arguments
		executable = "taskset"
	# Piped rather than inherited, so what a worker prints goes out above the
	# progress bar instead of over it. Quiet, so that's only warnings and errors.
	var process := OS.execute_with_pipe(executable, arguments, false)
	_progress.add_output_pipe(process["stdio"])
	_progress.add_output_pipe(process["stderr"])
	return process["pid"]

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
		DirAccess.remove_absolute(worker_progress_path(worker))
	finished.emit(_results)

static func worker_specs_path(worker: int) -> String:
	return "%s/specs_%d.json" % [WORKER_DIR, worker]

static func worker_results_path(worker: int) -> String:
	return "%s/results_%d.json" % [WORKER_DIR, worker]

static func worker_progress_path(worker: int) -> String:
	return "%s/progress_%d.txt" % [WORKER_DIR, worker]

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
		elif car.body.global_position.x >= finish_x():
			spec["time"] = snappedf(_batch_elapsed, 0.01)
			spec["distance"] = finish_x() - SPAWN_X
			# Done cars would otherwise keep simulating until the batch's
			# slowest car gives up.
			car.root.queue_free()
			_report_progress()
		else:
			var distance := snappedf(car.body.global_position.x - SPAWN_X, 1.0)
			spec["distance"] = maxf(spec["distance"], distance) if on_hill else distance
			all_done = false
	if all_done or _batch_elapsed >= (HILL_TIME_LIMIT if on_hill else TIME_LIMIT):
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
		var car := CarAssembler.assemble_from_car_data(RaceProgression.rival_car_model(spec),
				_batch_root, Vector2(SPAWN_X, floor_y))
		remove_engine_sound(car)
		_batch_specs.append(spec)
		_batch_cars.append(car)

func _finish_batch() -> void:
	for spec in _batch_specs:
		if not spec.has("time"):
			spec["time"] = RaceProgression.DID_NOT_FINISH
		_results.append(spec)
	_batch_root.queue_free()
	_batch_root = null
	_report_progress()
	if _pending.is_empty():
		finished.emit(_results)
	else:
		_start_batch.call_deferred()

## Cars done so far, counting the ones already over the line in this batch,
## so the bar moves before a batch's slowest car gives up.
func _report_progress() -> void:
	var done := _results.size()
	if _batch_root != null:
		done += _batch_specs.filter(func(spec: Dictionary) -> bool: return spec.has("time")).size()
	if progress_path.is_empty():
		print("time trial: %d / %d" % [done, _total])
	else:
		ToolProgress.write_worker_file(progress_path, done)

## Nobody hears a time trial, and synthesizing engine sound was most of each
## frame's cost. It only reads the wheels, so the race comes out the same.
static func remove_engine_sound(car: CarAssembler.AssembledCar) -> void:
	for child in car.body.get_children():
		if child is EngineSound:
			child.free()

func finish_x() -> float:
	return HILL_FINISH_X if on_hill else FINISH_X

func _add_floor(floor_y: float) -> void:
	if on_hill:
		var slope := StaticBody2D.new()
		slope.position.y = floor_y
		_batch_root.add_child(slope)
		_hill_profile.build_slab_collision(slope)
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8000.0, 60.0)
	var shape := CollisionShape2D.new()
	shape.shape = rectangle
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(3400.0, floor_y + 30.0)
	floor_body.add_child(shape)
	_batch_root.add_child(floor_body)
