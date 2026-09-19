class_name RaceController
extends Node2D
## Watches registered cars' body x-position against a finish line and
## declares a winner. No scripted "slow down on bump" logic lives here —
## collisions between cars are real RigidBody2D physics happening on their
## own; this node only observes position.
##
## Crossing the finish line doesn't end the race: each car's boost kicks on
## and stays on, so it genuinely accelerates hard over the runway past the
## line and slams into the wall (see track_multi.tscn's EndWall) instead
## of just falling off the end of the track. The race only wraps up once
## every car has crossed (or been destroyed), or max_duration runs out.

@export var finish_x: float = 2000.0
@export var max_duration: float = 20.0
@export var camera_path: NodePath
@export var finish_boost_force: float = 180000.0
## Y the camera locks to (at x = finish_x) once the first car crosses —
## should sit roughly centered across the lanes.
@export var camera_focus_y: float = 575.0
## If set, the game changes back to this scene once the race ends — used by
## the world map's drag strip so finishing a race drops you back onto the
## map instead of leaving you stranded on the track. Empty means "stay put"
## (standalone test scenes). Headless runs always just quit instead.
@export_file("*.tscn") var exit_scene_path: String = ""

var camera: CameraFollow
var _entries: Array[Dictionary] = []
var _elapsed := 0.0
var _race_over := false
var _winner_name := ""
var _log_timer := 0.0
const LOG_INTERVAL := 1.0

func _ready() -> void:
	camera = get_node_or_null(camera_path) as CameraFollow
	# CarRig children finish assembling in their own _ready() before this
	# one runs (Godot calls _ready bottom-up), so `assembled` is populated.
	for child in get_children():
		if child is CarRig:
			register_car(child.name, child.assembled)
	if camera != null:
		var bodies: Array[Node2D] = []
		for entry in _entries:
			bodies.append(entry["car"].body)
		camera.targets = bodies

func register_car(car_name: String, car: CarAssembler.AssembledCar) -> void:
	_entries.append({"name": car_name, "car": car, "finished": false})

func _physics_process(delta: float) -> void:
	if _race_over:
		return
	_elapsed += delta
	_log_timer += delta
	if _log_timer >= LOG_INTERVAL:
		_log_timer = 0.0
		_log_status()

	var all_finished := true
	for entry in _entries:
		if entry["finished"]:
			continue
		var car: CarAssembler.AssembledCar = entry["car"]
		if not is_instance_valid(car.body):
			# Body shattered before crossing the line — car's out of the race.
			entry["finished"] = true
			continue
		if car.body.global_position.x >= finish_x:
			_finish_car(entry)
		else:
			all_finished = false

	if all_finished:
		_end_race("ALL FINISHED")
	elif _elapsed >= max_duration:
		_end_race("TIMEOUT")

func _finish_car(entry: Dictionary) -> void:
	entry["finished"] = true
	var car: CarAssembler.AssembledCar = entry["car"]
	car.body.boost_force = finish_boost_force
	if _winner_name.is_empty():
		_winner_name = entry["name"]
		print(">>> WINNER: %s at t=%.2fs" % [_winner_name, _elapsed])
		if camera != null:
			camera.lock_on(Vector2(finish_x, camera_focus_y))
	else:
		print("    %s crosses at t=%.2fs" % [entry["name"], _elapsed])

func _log_status() -> void:
	for entry in _entries:
		var car: CarAssembler.AssembledCar = entry["car"]
		if not is_instance_valid(car.body):
			print("[t=%.1f] %s DESTROYED" % [_elapsed, entry["name"]])
			continue
		var wheel_speeds: Array = []
		for wheel in car.wheels:
			if is_instance_valid(wheel):
				wheel_speeds.append(snappedf(wheel.angular_velocity, 0.01))
		print("[t=%.1f] %s x=%.1f y=%.1f wheel_w=%s" % [_elapsed, entry["name"], car.body.global_position.x, car.body.global_position.y, str(wheel_speeds)])

func _end_race(reason: String) -> void:
	_race_over = true
	print(">>> RACE OVER (%s) after %.2fs" % [reason, _elapsed])
	for entry in _entries:
		var car: CarAssembler.AssembledCar = entry["car"]
		if not is_instance_valid(car.body):
			print("    %s DESTROYED" % entry["name"])
			continue
		print("    %s final x=%.1f%s" % [entry["name"], car.body.global_position.x, " [finished]" if entry["finished"] else ""])
	_maybe_quit()

func _maybe_quit() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
	elif not exit_scene_path.is_empty():
		get_tree().change_scene_to_file(exit_scene_path)
