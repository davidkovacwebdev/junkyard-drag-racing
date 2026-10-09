extends Node2D
## Bakes data/rival_roster.json: random junk cars built from the PartDatabase
## catalog, each raced alone on a flat strip and timed. RaceProgression picks
## drag strip opponents out of it by finish time, so difficulty is based on how
## fast a car actually is rather than on its parts' star ratings. Rerun after
## adding or retuning parts:
##   godot --headless --fixed-fps 60 res://tools/build_rival_roster.tscn
## or tools/build_all_rosters.sh for the drag, hill and derby rosters in one go.
##
## With `-- --hill` it bakes data/hill_rival_roster.json instead: the same kind
## of cars, each run up the hill climb. A car that never makes the summit gets
## the time it would have taken at the pace it managed, so the hill roster
## sorts and picks by "time" exactly like the drag one.
##
## With `-- --derby` it bakes data/derby_rival_roster.json: the same cars
## rated for the demolition derby from their parts (DerbyRating), ranked by
## "weakness" instead of time.

const ROSTER_SIZE := 1000
## Share of the roster wearing extras. Races pick bare or dressed-up cars by
## tier (RaceProgression.RIVAL_ACCESSORY_SHARE), so both need plenty of cars
## at every speed.
const ACCESSORY_CAR_SHARE := 0.5
## Chance each further spot gets an extra, once a car wears one.
const EXTRA_SPOT_CHANCE := 0.35
const RNG_SEED := 1337

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = RNG_SEED
	var specs: Array[Dictionary] = []
	for i in ROSTER_SIZE:
		specs.append(_random_spec())
	if _on_derby():
		var progress := ToolProgress.new(_progress_label("derby"), specs.size(), "cars")
		DerbyRating.rate_all(specs, self, progress)
		progress.finish()
		_save_derby(specs)
		return
	var trial := TimeTrial.new()
	trial.on_hill = _on_hill()
	trial.progress_label = _progress_label("hill climb" if _on_hill() else "drag")
	add_child(trial)
	trial.finished.connect(_save)
	trial.run(specs)

## Every wheel mount rolls its own wheel, so rivals run mismatched pairs like a
## real junkyard build would. Only junk-pile parts: one-of-a-kind ones (Vern,
## the Scrap Dealer, the horse...) stay the player's.
func _random_spec() -> Dictionary:
	var body: BodyPartData = PartDatabase.junk_bodies[_rng.randi() % PartDatabase.junk_bodies.size()]
	var engine: EnginePartData = PartDatabase.junk_engines[_rng.randi() % PartDatabase.junk_engines.size()]
	var wheels: Array[String] = []
	for i in PartDatabase.wheel_mount_count(body):
		wheels.append(PartDatabase.junk_wheels[_rng.randi() % PartDatabase.junk_wheels.size()].scene_path)
	return {"body": body.scene_path, "engine": engine.scene_path, "wheels": wheels, "accessories": _random_accessories()}

## None for half the cars; for the rest, one extra on a random spot and maybe
## more on the others.
func _random_accessories() -> Array[String]:
	var accessories: Array[String] = []
	if _rng.randf() >= ACCESSORY_CAR_SHARE:
		return accessories
	var spots := AccessoryPartData.Spot.values()
	var first_spot: int = spots[_rng.randi() % spots.size()]
	for spot in spots:
		if spot != first_spot and _rng.randf() >= EXTRA_SPOT_CHANCE:
			continue
		var options := PartDatabase.junk_accessories.filter(func(accessory: AccessoryPartData) -> bool:
			return accessory.spot == spot)
		accessories.append(options[_rng.randi() % options.size()].scene_path)
	return accessories

func _save(results: Array[Dictionary]) -> void:
	var roster: Array[Dictionary] = []
	for result in results:
		var time := float(result["time"])
		if _on_hill() and time >= RaceProgression.DID_NOT_FINISH and float(result["distance"]) > 0.0:
			var pace_time := TimeTrial.HILL_TIME_LIMIT * (TimeTrial.HILL_FINISH_X - TimeTrial.SPAWN_X) / float(result["distance"])
			time = minf(snappedf(pace_time, 0.01), RaceProgression.DID_NOT_FINISH)
		roster.append({"body": result["body"], "engine": result["engine"], "wheels": result["wheels"],
				"accessories": result["accessories"], "time": time})
	_write_roster(roster, "time", RaceProgression.HILL_ROSTER_PATH if _on_hill() else RaceProgression.ROSTER_PATH)

func _save_derby(results: Array[Dictionary]) -> void:
	var roster: Array[Dictionary] = []
	for result in results:
		roster.append({"body": result["body"], "engine": result["engine"], "wheels": result["wheels"],
				"accessories": result["accessories"], "weakness": result["weakness"]})
	_write_roster(roster, "weakness", RaceProgression.DERBY_ROSTER_PATH)

func _write_roster(roster: Array[Dictionary], key: String, path: String) -> void:
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a[key]) < float(b[key]))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(roster, "\t"))
	file.close()
	print("rival roster: wrote %s" % path)
	get_tree().quit()

## `-- --stage=2/3` (from tools/build_all_rosters.sh) prefixes the bar with
## which roster of how many this is.
static func _progress_label(roster_name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			return "[%s] %s" % [arg.trim_prefix("--stage="), roster_name]
	return roster_name

static func _on_hill() -> bool:
	return "--hill" in OS.get_cmdline_user_args()

static func _on_derby() -> bool:
	return "--derby" in OS.get_cmdline_user_args()
