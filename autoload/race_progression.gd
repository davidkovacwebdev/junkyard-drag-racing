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

## Manual tiers offered at the drag strip's pre-race menu (DragStripMenu) —
## independent of `races_won`, so the player can pick how much to risk
## rather than always racing whatever the campaign ladder currently hands
## out. Tier par times bracket the whole `races_won` range above (68.5 down
## to the 23.0 floor), and entry fees roughly triple each step.
const TIER_PAR_TIMES := { 1: 55.0, 2: 40.0, 3: 28.0, 4: 22.0 }
const TIER_ENTRY_FEES := { 1: 40, 2: 100, 3: 220, 4: 450 }
## Winning a paid-entry race pays back this many times the entry fee (so a
## win nets 3x the fee on top of getting it back); winning a bet (see
## DragStripMenu) pays back 3x the stake instead — driving risks more, so it
## pays more.
const ENTRY_WIN_MULTIPLIER := 4

## Sets of one-shot fields DragStripMenu writes just before
## change_scene_to_packed() into the race, since a fresh scene has no other
## way to receive parameters. single_lane_race_setup.gd reads and clears its
## own copies of these the instant it starts, so anything reached directly
## (the T-key test entrance, say) falls back to normal behaviour untouched.
## -1 / empty means "not set, use the normal default".
var pending_tier: int = -1
## Which of Inventory.owned_cars to race, or -1 for get_selected_car().
var pending_car_index: int = -1
## False for a spectator-only "watch the AI field race" — see
## DragStripMenu's betting flow. No player car is registered at all.
var pending_include_player: bool = true
## Entry fee already charged for this race, so a win knows how much to pay
## out — captured once, since `pending_tier`'s fee could otherwise be
## re-read after being reset.
var pending_entry_fee: int = 0
## The exact rival field DragStripMenu already showed the player and took a
## bet against — reused as-is (not re-rolled) so the car bet on is the
## actual car that races. Empty means "roll a fresh field the normal way".
var pending_bet_field: Array[Dictionary] = []

## Written by single_lane_race_setup.gd once a spectator-only (no player)
## race finishes, so DragStripMenu can resolve the bet when the scene
## returns to it. `last_ai_race_field_names` is each rival's registered
## `RaceController` name, in the same order as `pending_bet_field`/the bet
## picker, so the menu can tell which field entry actually won without
## having to re-derive a car's display name from its parts.
var last_ai_race_winner: String = ""
var last_ai_race_field_names: Array[String] = []
## What DragStripMenu bet on, captured the same way as pending_entry_fee so
## the menu can resolve the bet once it reads last_ai_race_winner back after
## the scene returns to it. `last_bet_car_name` matches one of
## `last_ai_race_field_names`.
var last_bet_amount: int = 0
var last_bet_car_name: String = ""

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

## The par time a manually-picked tier (1-4) races at — independent of
## `races_won`. Falls back to the normal campaign par for anything outside
## 1-4, so a stray/invalid tier can't break a race.
func par_time_for_tier(tier: int) -> float:
	return TIER_PAR_TIMES.get(tier, par_time())

func entry_fee_for_tier(tier: int) -> int:
	return int(TIER_ENTRY_FEES.get(tier, 0))

## `count` rival specs ({"body", "engine", "wheels"} scene paths plus their
## roster "time"), in random lane order.
func pick_rivals(count: int) -> Array[Dictionary]:
	return _pick_rivals_at_par(count, par_time())

## Same as pick_rivals(), but at a manually-picked tier's par time instead
## of the campaign's races-won-based one — see DragStripMenu.
func pick_rivals_for_tier(count: int, tier: int) -> Array[Dictionary]:
	return _pick_rivals_at_par(count, par_time_for_tier(tier))

func _pick_rivals_at_par(count: int, par: float) -> Array[Dictionary]:
	var rivals: Array[Dictionary] = []
	if count <= 0 or _roster.is_empty():
		return rivals
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
