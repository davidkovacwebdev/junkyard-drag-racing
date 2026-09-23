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
## map instead of leaving you stranded on the track. Empty falls back to
## DEFAULT_EXIT_SCENE. Headless runs always just quit instead.
@export_file("*.tscn") var exit_scene_path: String = ""
## How long to sit on the finished/wrecked scene before actually leaving —
## 0 keeps the original instant handoff (the drag strip: other cars are
## usually still finishing, so the moment every one of them is done there's
## nothing left to look at). A single-car scene needs this above 0: with
## just one entry, that car being destroyed alone satisfies "all
## finished" and would otherwise cut away the very same physics step the
## crash happens, before PartShatter's pieces have even had a frame to
## fly.
@export var end_delay: float = 0.0
## Where Escape (and the end-of-race handoff) goes when `exit_scene_path`
## isn't set. Escape always has to get you out of a race, so there's a hard
## fallback rather than a dead key on the standalone test scenes.
const DEFAULT_EXIT_SCENE := "res://scenes/world/main.tscn"

var camera: CameraFollow
var _entries: Array[Dictionary] = []
var _elapsed := 0.0
var _race_over := false
var _winner_name := ""
var _log_timer := 0.0
## Set the moment we start leaving, so Escape and the end-of-race handoff
## can both fire without queueing two scene changes.
var _exiting := false
const LOG_INTERVAL := 1.0

func _ready() -> void:
	DayNightCycle.advance_hours(4.0)
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

## Escape always leaves the race — mid-race, after the flag, or while the
## cars are still assembling. Handled in _input rather than _unhandled_input
## so no on-screen UI can swallow the key first. Matches the physical-key
## style used elsewhere (garage.gd) plus the built-in ui_cancel action.
func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel") \
			or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		exit_race()

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
	if end_delay > 0.0:
		get_tree().create_timer(end_delay).timeout.connect(exit_race)
	else:
		exit_race()

## Single way out of a race: back to `exit_scene_path`, or DEFAULT_EXIT_SCENE
## when the scene doesn't set one. Headless runs quit so test runs don't hang.
func exit_race() -> void:
	if _exiting:
		return
	_exiting = true
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	var path := exit_scene_path if not exit_scene_path.is_empty() else DEFAULT_EXIT_SCENE
	get_tree().change_scene_to_file(path)
