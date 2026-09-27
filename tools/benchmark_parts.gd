extends Node2D
## Races every part in the catalog on reference cars and prints how fast each
## one really is, next to its tier and speed stars, so tuning can be checked
## against actual races instead of the stat sheet:
##   godot --headless --fixed-fps 60 res://tools/benchmark_parts.tscn
##
## Wheels run as a pair on each reference engine, plus once mixed with the
## reference wheel in either slot. Engines run on reference wheels and on a bad
## pair. Bodies run on reference wheels with a weak and a mid engine.
## A car that never finishes is scored by extrapolating its pace to the finish.

const REFERENCE_BODY := "res://scenes/parts/bodies/body_wrecked_car.tscn"
const REFERENCE_WHEEL := "res://scenes/parts/wheels/wheel_standard.tscn"
const BAD_WHEEL := "res://scenes/parts/wheels/wheel_tv.tscn"
const WEAK_ENGINE := "res://scenes/parts/engines/engine_lawn_mower.tscn"
const MID_ENGINE := "res://scenes/parts/engines/engine_v6.tscn"
const STRONG_ENGINE := "res://scenes/parts/engines/engine_angle_grinder.tscn"

func _ready() -> void:
	var specs: Array[Dictionary] = []
	for wheel in PartDatabase.wheels:
		for engine_path in [WEAK_ENGINE, MID_ENGINE, STRONG_ENGINE]:
			specs.append(_spec(wheel, REFERENCE_BODY, engine_path, [wheel.scene_path, wheel.scene_path]))
		specs.append(_spec(wheel, REFERENCE_BODY, MID_ENGINE, [wheel.scene_path, REFERENCE_WHEEL]))
		specs.append(_spec(wheel, REFERENCE_BODY, MID_ENGINE, [REFERENCE_WHEEL, wheel.scene_path]))
	for engine in PartDatabase.engines:
		for wheel_path in [REFERENCE_WHEEL, BAD_WHEEL]:
			specs.append(_spec(engine, REFERENCE_BODY, engine.scene_path, [wheel_path, wheel_path]))
	for body in PartDatabase.bodies:
		var wheels: Array[String] = []
		for i in PartDatabase.wheel_mount_count(body):
			wheels.append(REFERENCE_WHEEL)
		for engine_path in [WEAK_ENGINE, MID_ENGINE]:
			specs.append(_spec(body, body.scene_path, engine_path, wheels))
	var trial := TimeTrial.new()
	add_child(trial)
	trial.finished.connect(_report)
	trial.run(specs)

func _spec(tested: PartData, body_path: String, engine_path: String, wheels: Array) -> Dictionary:
	return {"tested": tested, "body": body_path, "engine": engine_path, "wheels": wheels}

## Seconds to the finish line, extrapolated from how far it got if it didn't make it.
static func effective_time(result: Dictionary) -> float:
	var time := float(result["time"])
	if time < RaceProgression.DID_NOT_FINISH:
		return time
	var distance := maxf(float(result["distance"]), 1.0)
	return minf(TimeTrial.TIME_LIMIT * (TimeTrial.FINISH_X - TimeTrial.SPAWN_X) / distance, 999.0)

func _report(results: Array[Dictionary]) -> void:
	for category in [PartData.Category.WHEEL, PartData.Category.ENGINE, PartData.Category.BODY]:
		var rows: Array[Dictionary] = []
		for part in _parts_in(category):
			var times: Array[float] = []
			var wrecks := 0
			for result in results:
				if result["tested"] == part:
					times.append(effective_time(result))
					wrecks += int(result["wrecked"])
			rows.append({"part": part, "times": times, "average": _average(times), "wrecks": wrecks})
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["average"] < b["average"])
		print("\n=== %s (avg effective seconds, fastest first)" % PartData.Category.keys()[category])
		for row in rows:
			var part: PartData = row["part"]
			var extra := " power=%.1f" % (part as EnginePartData).power if part is EnginePartData else ""
			print("BENCH %-28s tier=%d speed=%.1f mass=%.1f dur=%.0f%s  avg=%6.1f  wrecks=%d  runs=%s" % [
				part.display_name, part.tier, part.speed, part.mass, part.durability, extra,
				row["average"], row["wrecks"], str(row["times"])])
	get_tree().quit()

static func _parts_in(category: PartData.Category) -> Array:
	match category:
		PartData.Category.WHEEL: return PartDatabase.wheels
		PartData.Category.ENGINE: return PartDatabase.engines
	return PartDatabase.bodies

static func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1.0)
