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

## Fired once when the race wraps up, before leaving the scene. `winner_name`
## is the first car across the line, or empty when nobody made it.
signal race_ended(winner_name: String)

@export var finish_x: float = 2000.0
## Grinding early-game parts can leave a race with no way to actually
## finish, so the race is hard-capped regardless of how far anyone got.
@export var max_duration: float = 60.0
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
## fly. Ignored whenever a results screen is set — that stays up until the
## player dismisses it instead of leaving on a timer (except headless runs,
## which have nobody to click anything and fall back to this).
@export var end_delay: float = 0.0
## If none of the still-alive cars have moved faster than
## stall_speed_threshold for this many seconds, the race ends early — bad
## enough parts can leave every car too weak to move at all, and without
## this the race would just sit doing nothing until max_duration runs out.
@export var stall_timeout: float = 5.0
## Speed (px/s) below which a car counts as "not moving" for the stall
## check above. Matches MIN_FORWARD_SPEED in single_lane_race_setup.gd,
## the threshold this codebase already uses elsewhere to call a car stopped.
@export var stall_speed_threshold: float = 25.0
## Off for scenes that aren't really a race — e.g. race_ramp.tscn's
## single-car jump, which is *meant* to settle to a stop — so the stall
## check doesn't fire there and cut the scene short.
@export var check_stalls: bool = true
## Optional countdown widget (see race_timer_hud.gd) fed with
## max_duration - elapsed every physics step. Left unset on scenes with no
## timer HUD.
@export var timer_hud_path: NodePath
## Optional podium screen (see results_screen.gd) shown with the top 3
## places once the race ends, before end_delay hands off to exit_scene_path.
@export var results_screen_path: NodePath
## Optional "give up" button (see surrender() below). Left unset on
## scenes with no such button.
@export var surrender_button_path: NodePath
## How long into the race the surrender button waits before appearing —
## no point offering an out before the player's even seen how this run's
## parts drive.
@export var surrender_delay: float = 5.0
## Played whenever a car crosses the line, on top of its backfire.
@export var finish_sound: StringName = &""
## Off for an arena with no line to cross (the demolition derby): its own
## setup decides who's out (knock_out) and who won (crown), and ranks the
## cars still running with set_progress.
@export var uses_finish_line: bool = true
## When nobody crossed the line by the end, the car ranked first still wins
## (the hill climb's highest climber, the derby's healthiest survivor).
@export var leader_wins_at_end: bool = false
## Above 0, a car that hasn't got any further along for this many seconds has
## given up and stops holding the race open (the hill climb, where a car that
## can't make the slope just rolls back and tries again forever).
@export var give_up_after: float = 0.0
## How much further than its best a car has to get to count as progress.
const GIVE_UP_PROGRESS := 40.0
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
var _stall_timer := 0.0
var _timer_hud: RaceTimerHud = null
var _results_screen: ResultsScreen = null
var _surrender_button: ScrapButton = null
## Entries in the order they actually crossed the finish line — 1st, 2nd,
## 3rd place is exactly this order, separate from `_entries`' registration
## order.
var _finish_order: Array[Dictionary] = []
var _knockout_count := 0
## Set the moment we start leaving, so Escape and the end-of-race handoff
## can both fire without queueing two scene changes.
var _exiting := false
const LOG_INTERVAL := 1.0

func _ready() -> void:
	DayNightCycle.advance_hours(4.0)
	add_child(DurabilityOverlay.new())
	camera = get_node_or_null(camera_path) as CameraFollow
	_timer_hud = get_node_or_null(timer_hud_path) as RaceTimerHud
	_results_screen = get_node_or_null(results_screen_path) as ResultsScreen
	_surrender_button = get_node_or_null(surrender_button_path) as ScrapButton
	if _surrender_button != null:
		_surrender_button.visible = false
		_surrender_button.pressed.connect(surrender)
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
	var body_part_data: PartData = car.body.part_data if car.body != null else null
	_entries.append({
		"name": car_name,
		"car": car,
		"finished": false,
		# Set true only by _finish_car() — actually crossing finish_x, as
		# opposed to "finished" which also covers being destroyed or the
		# race ending under it. Standings need to tell those apart.
		"crossed": false,
		# Ranks cars that never crossed the line: on a track, the furthest x
		# reached while the body was still valid; in an arena, whatever its
		# setup reports through set_progress().
		"progress": -INF,
		# Where the car last made GIVE_UP_PROGRESS of headway, and when.
		"progress_mark": -INF,
		"last_progress_time": 0.0,
		# Order knocked out of an arena (0 first), or -1 while still in it.
		"knockout_order": -1,
		"body_part_data": body_part_data,
	})

## Escape always leaves the race — mid-race, after the flag, or while the
## cars are still assembling. Handled in _input rather than _unhandled_input
## so no on-screen UI can swallow the key first. Matches the physical-key
## style used elsewhere (garage.gd) plus the built-in ui_cancel action.
##
## Once the results screen is up, a left click dismisses it too — it has no
## button of its own, so this is the only way to continue past it besides
## Escape, and it gets its own click sound since (unlike a mid-race Escape)
## it's a deliberate "I'm done looking" UI action.
func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var showing_results := _race_over and _results_screen != null
	var is_cancel: bool = (
			event.is_action("ui_cancel")
			or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE))
	var is_click: bool = (
			showing_results and event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not (is_cancel or is_click):
		return
	get_viewport().set_input_as_handled()
	if showing_results:
		Sfx.play(&"ui_click", Sfx.UI_CLICK_VOLUME_DB)
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
		if not uses_finish_line:
			all_finished = false
			continue
		var x := car.body.global_position.x
		if x > entry["progress_mark"] + GIVE_UP_PROGRESS:
			entry["progress_mark"] = x
			entry["last_progress_time"] = _elapsed
		entry["progress"] = maxf(entry["progress"], x)
		if x >= finish_x:
			_finish_car(entry)
		elif give_up_after > 0.0 and _elapsed - entry["last_progress_time"] > give_up_after:
			entry["finished"] = true
			print("    %s gives up at x=%.0f" % [entry["name"], entry["progress"]])
		else:
			all_finished = false

	_update_stall_timer(delta)
	if _timer_hud != null:
		_timer_hud.set_seconds_remaining(max_duration - _elapsed)
	if _surrender_button != null and not _surrender_button.visible and _elapsed >= surrender_delay:
		_surrender_button.visible = true

	if all_finished:
		_end_race("ALL FINISHED")
	elif _elapsed >= max_duration:
		_end_race("TIMEOUT")
	elif check_stalls and _stall_timer >= stall_timeout:
		_end_race("STALLED")

## Ticks up while every still-racing car is under stall_speed_threshold,
## resets the instant any one of them isn't — so a single car limping
## forward is enough to keep the race alive, but a full grid stuck on bad
## parts won't just sit there until max_duration.
func _update_stall_timer(delta: float) -> void:
	if not check_stalls:
		return
	var any_active := false
	var any_moving := false
	for entry in _entries:
		if entry["finished"]:
			continue
		var car: CarAssembler.AssembledCar = entry["car"]
		if not is_instance_valid(car.body):
			continue
		any_active = true
		if car.body.linear_velocity.length() > stall_speed_threshold:
			any_moving = true
			break
	if any_active and not any_moving:
		_stall_timer += delta
	else:
		_stall_timer = 0.0

func _finish_car(entry: Dictionary) -> void:
	entry["finished"] = true
	entry["crossed"] = true
	_finish_order.append(entry)
	var car: CarAssembler.AssembledCar = entry["car"]
	if is_instance_valid(car.body) and finish_boost_force > 0.0:
		car.body.boost_force = finish_boost_force
		RaceCarAudio.play(self, &"backfire", car.body.global_position, -2.0)
	if is_instance_valid(car.body) and finish_sound != &"" and uses_finish_line:
		Sfx.play(finish_sound, -6.0, 0.04)
	if _winner_name.is_empty():
		_winner_name = entry["name"]
		print(">>> WINNER: %s at t=%.2fs" % [_winner_name, _elapsed])
		if camera != null and uses_finish_line:
			camera.lock_on(Vector2(finish_x, camera_focus_y))
	else:
		print("    %s crosses at t=%.2fs" % [entry["name"], _elapsed])

## Arena races: `car_name` is out. Knocked-out cars rank below every car
## still running, the last one out highest.
func knock_out(car_name: String) -> void:
	var entry := _entry_named(car_name)
	if entry.is_empty() or entry["knockout_order"] >= 0 or entry["crossed"]:
		return
	entry["finished"] = true
	entry["knockout_order"] = _knockout_count
	_knockout_count += 1
	print("    %s knocked out at t=%.2fs" % [car_name, _elapsed])

## Arena races: `car_name` won outright, as if it crossed the line.
func crown(car_name: String) -> void:
	var entry := _entry_named(car_name)
	if not entry.is_empty() and not entry["crossed"]:
		_finish_car(entry)

## Arena races: how well a still-running car is doing, higher is better.
func set_progress(car_name: String, progress: float) -> void:
	var entry := _entry_named(car_name)
	if not entry.is_empty():
		entry["progress"] = progress

func _entry_named(car_name: String) -> Dictionary:
	for entry in _entries:
		if entry["name"] == car_name:
			return entry
	return {}

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

## Bails out of a still-running race — giving up on a bad build beats
## grinding out the rest of max_duration. AI cars are ranked exactly as if
## the clock had run out this instant; the player is dropped to last no
## matter their own position, since surrendering means conceding, not
## "whoever's ahead when I click wins".
func surrender() -> void:
	if _race_over:
		return
	_end_race("SURRENDER")

## Cars that actually crossed the line, in crossing order, then everyone
## else (still racing or destroyed) ranked by how far they got, then any
## knocked out of an arena, the last one out first — so a race
## that ends by TIMEOUT or STALLED before anyone finishes still produces a
## sensible podium instead of an empty one. `force_player_last` is for
## surrender(): the player's own entry gets moved to the very end
## regardless of where it would otherwise land.
func _compute_standings(force_player_last: bool = false) -> Array[Dictionary]:
	var standings: Array[Dictionary] = _finish_order.duplicate()
	var rest: Array[Dictionary] = []
	var knocked_out: Array[Dictionary] = []
	for entry in _entries:
		if entry["crossed"]:
			continue
		if entry["knockout_order"] >= 0:
			knocked_out.append(entry)
		else:
			rest.append(entry)
	rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["progress"] > b["progress"])
	knocked_out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["knockout_order"] > b["knockout_order"])
	standings.append_array(rest)
	standings.append_array(knocked_out)
	if force_player_last:
		for i in standings.size():
			if (standings[i]["name"] as String).begins_with("Player_"):
				standings.append(standings.pop_at(i))
				break
	return standings

## Top 3 standings turned into what ResultsScreen actually shows: the
## player's own entry stays "Player", every AI car gets a random, distinct
## placeholder driver name (see name_gen.gd) picked fresh each race.
func _build_results_data(standings: Array[Dictionary]) -> Array[Dictionary]:
	var top := standings.slice(0, mini(3, standings.size()))
	var ai_count := 0
	for entry in top:
		if not (entry["name"] as String).begins_with("Player_"):
			ai_count += 1
	var random_names := NameGen.random_names(ai_count)
	var result: Array[Dictionary] = []
	var name_i := 0
	for entry in top:
		var display_name: String
		if (entry["name"] as String).begins_with("Player_"):
			display_name = "Player"
		else:
			display_name = random_names[name_i]
			name_i += 1
		result.append({"name": display_name, "body_part_data": entry["body_part_data"]})
	return result

func _end_race(reason: String) -> void:
	_race_over = true
	print(">>> RACE OVER (%s) after %.2fs" % [reason, _elapsed])
	if _surrender_button != null:
		_surrender_button.visible = false
	if reason == "STALLED" or reason == "SURRENDER":
		Sfx.play(&"race_stalled", -6.0, 0.0)
	else:
		Sfx.play(&"results_fanfare", -4.0, 0.0)
	var standings := _compute_standings(reason == "SURRENDER")
	if _winner_name.is_empty() and leader_wins_at_end and not standings.is_empty():
		_winner_name = standings[0]["name"]
		print(">>> WINNER (furthest): %s" % _winner_name)
	if _results_screen != null:
		_results_screen.show_results(_build_results_data(standings))
	for entry in _entries:
		var car: CarAssembler.AssembledCar = entry["car"]
		if not is_instance_valid(car.body):
			print("    %s DESTROYED" % entry["name"])
			continue
		print("    %s final x=%.1f%s" % [entry["name"], car.body.global_position.x, " [finished]" if entry["finished"] else ""])
	race_ended.emit(_winner_name)
	# A results screen stays up until the player dismisses it (see _input) —
	# no timer needed. Headless runs have nobody to click anything, so they
	# always fall through to the old timer/instant handoff instead of
	# hanging forever.
	if _results_screen != null and DisplayServer.get_name() != "headless":
		return
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
