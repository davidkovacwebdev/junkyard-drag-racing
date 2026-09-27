extends Node2D
## Bakes data/rival_roster.json: random junk cars built from the PartDatabase
## catalog, each raced alone on a flat strip and timed. RaceProgression picks
## drag strip opponents out of it by finish time, so difficulty is based on how
## fast a car actually is rather than on its parts' star ratings. Rerun after
## adding or retuning parts:
##   godot --headless --fixed-fps 60 res://tools/build_rival_roster.tscn

const ROSTER_SIZE := 240
const RNG_SEED := 1337

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = RNG_SEED
	var specs: Array[Dictionary] = []
	for i in ROSTER_SIZE:
		specs.append(_random_spec())
	var trial := TimeTrial.new()
	add_child(trial)
	trial.finished.connect(_save)
	trial.run(specs)

## Every wheel mount rolls its own wheel, so rivals run mismatched pairs like a
## real junkyard build would.
func _random_spec() -> Dictionary:
	var body: BodyPartData = PartDatabase.bodies[_rng.randi() % PartDatabase.bodies.size()]
	var engine: EnginePartData = PartDatabase.engines[_rng.randi() % PartDatabase.engines.size()]
	var wheels: Array[String] = []
	for i in PartDatabase.wheel_mount_count(body):
		wheels.append(PartDatabase.wheels[_rng.randi() % PartDatabase.wheels.size()].scene_path)
	return {"body": body.scene_path, "engine": engine.scene_path, "wheels": wheels}

func _save(results: Array[Dictionary]) -> void:
	var roster: Array[Dictionary] = []
	for result in results:
		roster.append({"body": result["body"], "engine": result["engine"], "wheels": result["wheels"], "time": result["time"]})
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"]))
	var file := FileAccess.open(RaceProgression.ROSTER_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(roster, "\t"))
	file.close()
	print("rival roster: wrote %s" % RaceProgression.ROSTER_PATH)
	get_tree().quit()
