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
## The same kind of cars timed up the hill climb instead (see
## tools/build_rival_roster.gd --hill): a fast drag car is often a hopeless
## climber, so the hill picks its rivals from how they climb.
const HILL_ROSTER_PATH := "res://data/hill_rival_roster.json"

## Which roster and tier pars a venue's rivals come from.
enum Course { DRAG, HILL }
## Roster time for a car that never reached the finish line.
const DID_NOT_FINISH := 999.0

## Tuned so Inventory's starter car wins ~45% of its first races, ~25% after one
## win, and then needs better parts to keep up.
const STARTING_PAR_TIME := 32.7
const PAR_TIME_PER_WIN := 0.93
## Roughly the quickest thing in the roster; par never asks for more.
const FASTEST_PAR_TIME := 18.6
## Headliner's time range, as multiples of par.
const HEADLINER_WINDOW := Vector2(0.85, 1.15)
## Filler rivals' time range, as multiples of the headliner's time.
const FILLER_WINDOW := Vector2(1.05, 1.6)

## Manual tiers offered at the drag strip's pre-race menu (DragStripMenu) —
## independent of `races_won`, so the player can pick how much to risk
## rather than always racing whatever the campaign ladder currently hands
## out. Tier par times bracket the whole `races_won` range above (32.7 down
## to the 18.6 floor), and entry fees roughly triple each step.
const TIER_PAR_TIMES := { 1: 47.0, 2: 33.0, 3: 22.5, 4: 17.5 }
## The hill's tier pars, at the same spots in the hill roster as the drag
## pars sit in the drag one.
## Tier 4's window only holds cars that reach the summit.
const HILL_TIER_PAR_TIMES := { 1: 150.0, 2: 98.0, 3: 75.0, 4: 30.0 }
const TIER_ENTRY_FEES := { 1: 40, 2: 100, 3: 220, 4: 450 }
## Winning a paid-entry race pays back this many times the entry fee (so a
## win nets 3x the fee on top of getting it back); winning a bet (see
## DragStripMenu) pays back 3x the stake instead — driving risks more, so it
## pays more.
const ENTRY_WIN_MULTIPLIER := 4
## Share of rivals wearing extras, by tier: a bolt-on is a rare sight at the
## bottom and common at the top. The roster times cars with their extras on,
## so this only picks which cars show up, not how fast they are.
const RIVAL_ACCESSORY_SHARE := { 1: 0.12, 2: 0.35, 3: 0.6, 4: 0.85 }

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
## The driver names the bet cards showed, in the same order as
## `pending_bet_field`, so the results board names the same drivers.
var pending_bet_names: Array[String] = []

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
## Whether that bet was on Roge Roger (see `roger_spec()`), for Grandpa's
## "Sure Thing" quest.
var last_bet_on_roger: bool = false

## Roge Roger: back in town and racing in the top division, in a car that
## belongs at the bottom of it. While Grandpa's "Sure Thing" is on, he's one
## of the cars in the top tier's bet field at the Drag Strip (see
## DragStripMenu).
const ROGER_NAME := "Roge Roger"
const ROGER_QUEST := &"roge_roger_bet"
const ROGER_TIER := 4
const ROGER_VENUE := "Drag Strip"

## Which race the shared pre-race menu (DragStripMenu) sends the player into,
## and the venue name it shows. Set by the RegistrationBooth they walked into,
## and kept across the menu <-> race loop so returning from a race stays at
## the same venue.
const DEFAULT_RACE_SCENE := "res://scenes/race/race_drag_strip.tscn"
var menu_race_scene: String = DEFAULT_RACE_SCENE
var menu_venue_name: String = "Drag Strip"
var menu_course: Course = Course.DRAG
## What the clerk tells you the venue is about; empty means the par time.
var menu_venue_rules: String = ""

var races_won: int = 0
var _rosters := {}

func _ready() -> void:
	_rosters[Course.DRAG] = _load_roster(ROSTER_PATH)
	_rosters[Course.HILL] = _load_roster(HILL_ROSTER_PATH)

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
func par_time_for_tier(tier: int, course: Course = Course.DRAG) -> float:
	return _tier_pars(course).get(tier, par_time())

func entry_fee_for_tier(tier: int) -> int:
	return int(TIER_ENTRY_FEES.get(tier, 0))

## `count` rival specs ({"body", "engine", "wheels", "accessories"} scene
## paths plus their roster "time"), in random lane order.
func pick_rivals(count: int) -> Array[Dictionary]:
	return _pick_rivals_at_par(count, par_time(), Course.DRAG)

## Same as pick_rivals(), but at a manually-picked tier's par time instead
## of the campaign's races-won-based one — see DragStripMenu.
func pick_rivals_for_tier(count: int, tier: int, course: Course = Course.DRAG) -> Array[Dictionary]:
	return _pick_rivals_at_par(count, par_time_for_tier(tier, course), course)

func _pick_rivals_at_par(count: int, par: float, course: Course) -> Array[Dictionary]:
	var rivals: Array[Dictionary] = []
	var roster: Array[Dictionary] = _rosters[course]
	if roster.is_empty():
		roster = _rosters[Course.DRAG]
	if count <= 0 or roster.is_empty():
		return rivals
	var accessory_share := _accessory_share_for_par(par, _tier_pars(course))
	var headliner := _pick_in_window(roster, par * HEADLINER_WINDOW.x, par * HEADLINER_WINDOW.y, par,
			randf() < accessory_share)
	rivals.append(headliner)
	var headliner_time := float(headliner["time"])
	for i in count - 1:
		rivals.append(_pick_in_window(roster, headliner_time * FILLER_WINDOW.x, headliner_time * FILLER_WINDOW.y,
				headliner_time * FILLER_WINDOW.y, randf() < accessory_share))
	rivals.shuffle()
	return rivals

## The tier whose par is closest to `par` decides how often rivals wear
## extras, so campaign races follow the same curve as picked tiers.
static func _accessory_share_for_par(par: float, tier_pars: Dictionary) -> float:
	var closest_tier := 1
	for tier in tier_pars:
		if absf(tier_pars[tier] - par) < absf(tier_pars[closest_tier] - par):
			closest_tier = tier
	return RIVAL_ACCESSORY_SHARE[closest_tier]

static func _tier_pars(course: Course) -> Dictionary:
	return HILL_TIER_PAR_TIMES if course == Course.HILL else TIER_PAR_TIMES

## Roge Roger's car: always the same one, the roster car timed closest to
## the bottom tier's par (no extras), so he's hopelessly outclassed.
func roger_spec() -> Dictionary:
	var roster: Array[Dictionary] = _rosters[Course.DRAG]
	var plain := roster.filter(func(entry: Dictionary) -> bool:
		return Array(entry.get("accessories", [])).is_empty())
	return _pick_in_window(plain, TIER_PAR_TIMES[1], TIER_PAR_TIMES[1], TIER_PAR_TIMES[1], false) \
			if not plain.is_empty() else roster[0]

## Whether Roge Roger turns up in `tier`'s bet field at `venue` right now.
func roger_is_racing(tier: int, venue: String) -> bool:
	return tier == ROGER_TIER and venue == ROGER_VENUE \
			and Quests.has_quest(ROGER_QUEST) and not Quests.is_ready(ROGER_QUEST)

## The full car a rival spec describes, built from throwaway PartData loads
## of its scene paths: what the bet card shows and what races.
static func rival_car_model(rival: Dictionary) -> CarModelData:
	var model := CarModelData.new()
	model.body = PartDatabase.load_part_data(rival["body"]) as BodyPartData
	model.engine = PartDatabase.load_part_data(rival["engine"]) as EnginePartData
	var wheels: Array[WheelPartData] = []
	for wheel_path in rival["wheels"]:
		wheels.append(PartDatabase.load_part_data(wheel_path) as WheelPartData)
	model.wheels = wheels
	var accessories: Array[AccessoryPartData] = []
	for accessory_path in rival.get("accessories", []):
		accessories.append(PartDatabase.load_part_data(accessory_path) as AccessoryPartData)
	model.accessories = accessories
	return model

## A random roster car timed between `fastest` and `slowest`, wearing extras
## or not as `with_accessories` asks (either kind if the window has none of
## that kind), or the one timed closest to `fallback_time` when none is.
static func _pick_in_window(roster: Array[Dictionary], fastest: float, slowest: float, fallback_time: float, with_accessories: bool) -> Dictionary:
	var candidates := roster.filter(func(entry: Dictionary) -> bool:
		var time := float(entry["time"])
		return time >= fastest and time <= slowest)
	var matching := candidates.filter(func(entry: Dictionary) -> bool:
		return Array(entry.get("accessories", [])).is_empty() != with_accessories)
	if not matching.is_empty():
		return matching.pick_random()
	if not candidates.is_empty():
		return candidates.pick_random()
	var closest: Dictionary = roster[0]
	for entry in roster:
		if absf(float(entry["time"]) - fallback_time) < absf(float(closest["time"]) - fallback_time):
			closest = entry
	return closest

## Roster entries whose part scenes all still exist, so renaming or deleting a
## part only drops the rivals built from it instead of breaking the race.
static func _load_roster(path: String) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return roster
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		push_error("RaceProgression: could not read %s" % path)
		return roster
	for entry in parsed:
		var scene_paths: Array = [entry["body"], entry["engine"]] + Array(entry["wheels"]) \
				+ Array(entry.get("accessories", []))
		if scene_paths.all(func(path: String) -> bool: return ResourceLoader.exists(path)):
			roster.append(entry)
	return roster
