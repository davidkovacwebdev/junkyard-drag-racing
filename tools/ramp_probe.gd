extends Node2D
## Sends reference cars down the ramp jump and prints how fast each one hits
## the kicker and the lip, what broke where, and whether it cleared the pit:
##   godot --headless --fixed-fps 60 res://tools/ramp_probe.tscn -- --no-save
##
## Every engine runs on the reference body and wheels, every body on reference
## wheels with the mid engine, every wheel pair on the reference body with the
## mid engine. With `--showcase`, only a few hand-built top cars run instead.

const TRACK_SCENE := "res://scenes/race/track_ramp_single.tscn"
const REFERENCE_BODY := "res://scenes/parts/bodies/body_wrecked_car.tscn"
const REFERENCE_WHEEL := "res://scenes/parts/wheels/wheel_standard.tscn"
const MID_ENGINE := "res://scenes/parts/engines/engine_v6.tscn"
const SPAWN_POSITION := Vector2(-200.0, 0.0)
const TRACK_SPACING := 8000.0
const CARS_PER_BATCH := 16
const TIME_LIMIT := 40.0
const KICKER_X := 3300.0
const LIP_X := 3830.0
const LANDING_X := 5330.0
const PIT_Y := 3050.0

var _pending: Array[Dictionary] = []
var _batch: Array[Dictionary] = []
var _batch_root: Node2D
var _elapsed := 0.0
var _outcome_counts := {}

## Body, engine, wheel (scene names under scenes/parts/) for --showcase.
const SHOWCASE := [
	["body_radiator", "engine_jet", "wheel_standard"],
	["body_gondola", "engine_jet", "wheel_tractor"],
	["body_ufo", "engine_jet", "wheel_tractor"],
	["body_fridge", "engine_v8", "wheel_tractor"],
	["body_ufo", "engine_v8", "wheel_tractor"],
	["body_gondola", "engine_firework_rocket", "wheel_tractor"],
	["body_classic", "engine_v6", "wheel_standard"],
	["body_cardboard_box", "engine_jet", "wheel_standard"],
]

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--showcase"):
		for build in SHOWCASE:
			var body := PartDatabase.load_part_data("res://scenes/parts/bodies/%s.tscn" % build[0]) as BodyPartData
			var wheels: Array[String] = []
			for i in PartDatabase.wheel_mount_count(body):
				wheels.append("res://scenes/parts/wheels/%s.tscn" % build[2])
			var tested := body.duplicate() as PartData
			tested.display_name = " + ".join(build)
			_pending.append(_spec(tested, body.scene_path, "res://scenes/parts/engines/%s.tscn" % build[1], wheels))
		_start_batch.call_deferred()
		return
	for engine in PartDatabase.engines:
		_pending.append(_spec(engine, REFERENCE_BODY, engine.scene_path, [REFERENCE_WHEEL, REFERENCE_WHEEL]))
	for body in PartDatabase.bodies:
		var wheels: Array[String] = []
		for i in PartDatabase.wheel_mount_count(body):
			wheels.append(REFERENCE_WHEEL)
		_pending.append(_spec(body, body.scene_path, MID_ENGINE, wheels))
	for wheel in PartDatabase.wheels:
		_pending.append(_spec(wheel, REFERENCE_BODY, MID_ENGINE, [wheel.scene_path, wheel.scene_path]))
	_start_batch.call_deferred()

func _spec(tested: PartData, body_path: String, engine_path: String, wheels: Array) -> Dictionary:
	return {"tested": tested, "body": body_path, "engine": engine_path, "wheels": wheels}

func _start_batch() -> void:
	_batch_root = Node2D.new()
	add_child(_batch_root)
	_elapsed = 0.0
	_batch.clear()
	var track_scene: PackedScene = load(TRACK_SCENE)
	for i in mini(CARS_PER_BATCH, _pending.size()):
		var run: Dictionary = _pending.pop_front()
		var offset := Vector2(0.0, i * TRACK_SPACING)
		var track: Node2D = track_scene.instantiate()
		track.position = offset
		_batch_root.add_child(track)
		var car := CarAssembler.assemble_from_car_data(RaceProgression.rival_car_model(run),
				_batch_root, SPAWN_POSITION + offset)
		TimeTrial.remove_engine_sound(car)
		CarAutosteer.switch_off(car.body)
		run["car"] = car
		run["offset"] = offset
		run["kicker_speed"] = -1.0
		run["lip_speed"] = -1.0
		run["max_speed"] = 0.0
		run["breaks"] = []
		run["outcome"] = ""
		for part: RigidBody2D in [car.body] + car.wheels:
			var damage := CarPartDamage.of(part)
			var label: String = damage.part_data.display_name if damage.part_data != null else part.name
			damage.broken.connect(func() -> void:
				var x := part.global_position.x if is_instance_valid(part) else -1.0
				var speed := part.linear_velocity.length() if is_instance_valid(part) else -1.0
				run["breaks"].append("%s@x%d,v%d" % [label, roundi(x), roundi(speed)]))
		_batch.append(run)

func _physics_process(delta: float) -> void:
	if _batch_root == null:
		return
	_elapsed += delta
	var all_done := true
	for run in _batch:
		if run["outcome"] != "":
			continue
		var car: CarAssembler.AssembledCar = run["car"]
		if not is_instance_valid(car.body):
			run["outcome"] = "WRECKED"
			continue
		var position := car.body.global_position - (run["offset"] as Vector2)
		var speed := car.body.linear_velocity.length()
		run["max_speed"] = maxf(run["max_speed"], speed)
		if run["kicker_speed"] < 0.0 and position.x >= KICKER_X:
			run["kicker_speed"] = speed
		if run["lip_speed"] < 0.0 and position.x >= LIP_X:
			run["lip_speed"] = speed
		if position.y > PIT_Y:
			run["outcome"] = "PIT"
		elif position.x > LANDING_X + 200.0 and position.y < 2700.0:
			run["outcome"] = "CLEARED"
		else:
			all_done = false
	if all_done or _elapsed >= TIME_LIMIT:
		_finish_batch()

func _finish_batch() -> void:
	for run in _batch:
		var tested: PartData = run["tested"]
		var outcome: String = run["outcome"] if run["outcome"] != "" else "STUCK"
		_outcome_counts[outcome] = _outcome_counts.get(outcome, 0) + 1
		print("RAMP %-30s %-8s kicker=%5d lip=%5d max=%5d breaks=%s" % [
			tested.display_name, outcome,
			roundi(run["kicker_speed"]), roundi(run["lip_speed"]), roundi(run["max_speed"]),
			", ".join(PackedStringArray(run["breaks"]))])
	_batch_root.queue_free()
	_batch_root = null
	if _pending.is_empty():
		print("RAMP TOTAL ", _outcome_counts)
		get_tree().quit()
	else:
		_start_batch.call_deferred()
