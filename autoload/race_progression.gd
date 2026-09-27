extends Node
## Drag strip difficulty (autoload singleton "RaceProgression"). Counts the
## player's wins and picks each race's opponents to match.
##
## Opponents come from data/rival_roster.json — junk cars that were actually
## raced and timed (see tools/build_rival_roster.gd) — so "harder" means
## measurably faster, not higher star ratings on paper.
##
## Difficulty is a par time: STARTING_PAR_TIME with zero wins, shrinking by
## PAR_TIME_PER_WIN every win. Each race has one headliner rival timed around
## par, and the rest of the field is slower filler. The headliner is what the
## player is really racing, so a car running at par wins about half the time,
## and the chance falls off smoothly rather than cliff-edging the moment any of
## five rivals happens to be quicker.

const ROSTER_PATH := "res://data/rival_roster.json"
## Roster time for a car that never reached the finish line.
const DID_NOT_FINISH := 999.0

## Tuned so Inventory's starter car wins ~45% of its first races, ~25% after one
## win, and then needs better parts to keep up.
const STARTING_PAR_TIME := 68.5
const PAR_TIME_PER_WIN := 0.93
## Roughly the quickest thing in the roster; par never asks for more.
const FASTEST_PAR_TIME := 23.0
## Headliner's time range, as multiples of par.
const HEADLINER_WINDOW := Vector2(0.85, 1.15)
## Filler rivals' time range, as multiples of the headliner's time.
const FILLER_WINDOW := Vector2(1.05, 1.6)

var races_won: int = 0
var _roster: Array[Dictionary] = []

func _ready() -> void:
	_roster = _load_roster()

func reset() -> void:
	races_won = 0

func record_race(player_won: bool) -> void:
	if player_won:
		races_won += 1

func par_time() -> float:
	return maxf(STARTING_PAR_TIME * pow(PAR_TIME_PER_WIN, races_won), FASTEST_PAR_TIME)

## `count` rival specs ({"body", "engine", "wheels"} scene paths plus their
## roster "time"), in random lane order.
func pick_rivals(count: int) -> Array[Dictionary]:
	var rivals: Array[Dictionary] = []
	if count <= 0 or _roster.is_empty():
		return rivals
	var par := par_time()
	var headliner := _pick_in_window(par * HEADLINER_WINDOW.x, par * HEADLINER_WINDOW.y, par)
	rivals.append(headliner)
	var headliner_time := float(headliner["time"])
	for i in count - 1:
		rivals.append(_pick_in_window(headliner_time * FILLER_WINDOW.x,
				headliner_time * FILLER_WINDOW.y, headliner_time * FILLER_WINDOW.y))
	rivals.shuffle()
	return rivals

## A random roster car timed between `fastest` and `slowest`, or the one timed
## closest to `fallback_time` when none is.
func _pick_in_window(fastest: float, slowest: float, fallback_time: float) -> Dictionary:
	var candidates := _roster.filter(func(entry: Dictionary) -> bool:
		var time := float(entry["time"])
		return time >= fastest and time <= slowest)
	if not candidates.is_empty():
		return candidates.pick_random()
	var closest: Dictionary = _roster[0]
	for entry in _roster:
		if absf(float(entry["time"]) - fallback_time) < absf(float(closest["time"]) - fallback_time):
			closest = entry
	return closest

## Roster entries whose part scenes all still exist, so renaming or deleting a
## part only drops the rivals built from it instead of breaking the race.
static func _load_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROSTER_PATH))
	if not parsed is Array:
		push_error("RaceProgression: could not read %s" % ROSTER_PATH)
		return roster
	for entry in parsed:
		var scene_paths: Array = [entry["body"], entry["engine"]] + Array(entry["wheels"])
		if scene_paths.all(func(path: String) -> bool: return ResourceLoader.exists(path)):
			roster.append(entry)
	return roster
