class_name HeliTestStory
extends Node
## "Test Pilot", between "Chains" and "King of the Hill". Added by
## StoryDirector.
##
## - Once "Chains" is handed in, Grandpa builds a one-man helicopter (out of
##   the engine and tail rotor from "Up, Up and Away"). It shows up in his
##   yard (MiniHeliPad) once the player's been off somewhere and come back,
##   and he sits there whacking it with his wrench.
## - Talking to him plays GrandpaMiniHeliCutscene, which gives the quest. Then
##   E at the helicopter climbs in, and MiniHeliFlight has the car: up over
##   everything, 30 seconds of fun, then it breaks down.
## - MiniHeliCrashCutscene brings it down somewhere random on the map (on
##   land, clear of things), and leaves the wreck (MiniHeliWreck) there for
##   good. Then it's back to Grandpa, whose GrandpaMiniHeliReportCutscene
##   hands the quest in.
##
## The crash spot is in Quests.notes ("crashed:x,y"), which is how the wreck
## comes back on every load. Reloading before the crash puts the helicopter
## back in the yard.

const GROUP := &"heli_test_story"
const QUEST := &"heli_test"
const CRASH_PATH := "res://cutscenes/mini_heli_crash.tres"
const PAD_NAME := "Grandpa's Helicopter"
## Where it's parked, from Grandpa's spot: out on the open grass down the
## yard, past the smoker and the pine. While it's there, he sits by its nose
## (WORKSHOP_FROM_PAD) to whack it, and goes back to his spot once it's gone.
const PAD_FROM_GRANDPA := Vector2(-720.0, 20.0)
const WORKSHOP_FROM_PAD := Vector2(200.0, 30.0)
## The player has to be this far off before it turns up in the yard.
const LEAVE_RANGE := 1200.0
## Grandpa whacks it this often while it waits, heard from this close.
const WHACK_EVERY := Vector2(2.2, 4.0)
const WHACK_RANGE := 1800.0
## Where it comes down, from where it gave out: always on the main island,
## never out past a bridge that's still closed.
const MAIN_ISLAND_PATH := ^"Terrain/Main Island"
## How far from where it gave out.
const CRASH_DISTANCE := Vector2(1500.0, 3500.0)
const CRASH_TRIES := 30
## Where the car's set down beside the wreck (MiniHeliCrashCutscene).
const CAR_FROM_WRECK := Vector2(280.0, 40.0)
const CRASHED := "crashed:"
## The main island's coastline in world space, read on first use.
var _main_island := PackedVector2Array()

var _pad: MiniHeliPad
var _wreck: MiniHeliWreck
var _flight: MiniHeliFlight
var _left_home := false
var _started := false
var _whack := 1.5
var _whacking := false
var _at_workshop := false

func _ready() -> void:
	add_to_group(GROUP)

## The helicopter in the yard (null before Grandpa's in the world).
func pad() -> MiniHeliPad:
	return _pad

func _process(delta: float) -> void:
	var grandpa := _grandpa()
	if grandpa == null:
		return
	_ensure_pad(grandpa)
	_ensure_wreck(grandpa)
	if GrandpaNpc.is_gone():
		_pad.set_shown(false)
		return
	var available := Quests.available.any(func(quest: QuestData) -> bool: return quest.id == QUEST)
	var active := Quests.has_quest(QUEST)
	var flyable := active and not Quests.is_ready(QUEST) and _crash_spot() == Vector2.INF and _flight == null
	if not _started:
		# Back on the map since it was unlocked: it's had time to be built.
		_started = true
		_left_home = available
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if available and not _left_home and car != null \
			and car.global_position.distance_to(grandpa.global_position) > LEAVE_RANGE:
		_left_home = true
	if Cutscenes.is_active():
		return
	_pad.set_shown((available and _left_home) or flyable)
	_pad.display_name = PAD_NAME if flyable else ""
	_move_grandpa(grandpa, _pad.visible or _flight != null)
	_update_whacking(grandpa, available and _left_home, car, delta)

## The start scene: the helicopter's out and Grandpa's at it, even if the
## player never left the yard.
func bring_grandpa_to_heli() -> void:
	var grandpa := _grandpa()
	if grandpa == null:
		return
	_ensure_pad(grandpa)
	_left_home = true
	_pad.set_shown(true)
	_move_grandpa(grandpa, true)

## By the helicopter while it's in the yard (or up in the air), back at his
## spot once it's crashed. Both happen while the player's away.
func _move_grandpa(grandpa: GrandpaNpc, by_heli: bool) -> void:
	if by_heli == _at_workshop:
		return
	_at_workshop = by_heli
	if by_heli:
		grandpa.global_position = _pad.global_position + WORKSHOP_FROM_PAD
		grandpa.face_wrench_toward(_pad.global_position)
	else:
		grandpa.global_position = StoryDirector.GRANDPA_SPOT
		grandpa.actor.face(grandpa.facing_right)

## While it waits for the player, Grandpa's at it with the wrench.
func _update_whacking(grandpa: GrandpaNpc, on: bool, car: Node2D, delta: float) -> void:
	if not on:
		_whacking = false
		return
	_whacking = true
	_whack -= delta
	if _whack > 0.0:
		return
	_whack = randf_range(WHACK_EVERY.x, WHACK_EVERY.y)
	if car == null or car.global_position.distance_to(grandpa.global_position) > WHACK_RANGE:
		return
	grandpa.face_wrench_toward(_pad.global_position)
	grandpa.bang(-10.0, true)
	Sfx.play_at(&"car_whack", _pad.global_position, -14.0, 0.1)

# --- Flying ---------------------------------------------------------------------------

## E at the helicopter: the player climbs in and it takes off.
func _board(_talker: Node) -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	if car == null or _flight != null or Cutscenes.is_active():
		return
	Sfx.play(&"door_close", -6.0, 0.0)
	_pad.set_shown(false)
	_flight = MiniHeliFlight.new()
	_flight.on_crash = _crash
	add_child(_flight)
	_flight.begin(car, _pad.global_position)

func _crash() -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	var scene := ResourceLoader.load(CRASH_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MiniHeliCrashCutscene
	if scene != null and car != null:
		scene.flight = _flight
		scene.crash_at = _pick_crash_spot(car)
		scene.place_wreck = _place_wreck_at
		await Cutscenes.play(scene)
	if is_instance_valid(_flight):
		_flight.finish()
	_flight = null
	if _crash_spot() == Vector2.INF and car != null:
		_place_wreck_at(car.global_position)
	Quests.goal_met(QUEST)
	SaveSystem.save_game()

## Somewhere a way off from where it gave out, on land, with room for the
## wreck and the car beside it. Failing that, the first such spot on the way
## back home.
func _pick_crash_spot(car: PlayerCar) -> Vector2:
	var from := car.global_position
	for i in CRASH_TRIES:
		var spot := from + Vector2.from_angle(randf() * TAU) * randf_range(CRASH_DISTANCE.x, CRASH_DISTANCE.y)
		if _room_for_wreck(car, spot):
			return spot
	var home := StoryDirector.OPENING_CAR_SPOT
	for i in range(1, 41):
		var spot := from.lerp(home, i / 40.0)
		if _room_for_wreck(car, spot):
			return spot
	return home + Vector2(600.0, 400.0)

## On the main island, off the road and any bridge, with the car fitting in
## beside it.
func _room_for_wreck(car: PlayerCar, spot: Vector2) -> bool:
	var car_spot := spot + CAR_FROM_WRECK
	if not _on_main_island(spot) or not _on_main_island(car_spot) \
			or BlockedBridge.any_deck_under(get_tree(), spot) or BlockedBridge.any_deck_under(get_tree(), car_spot):
		return false
	var roads := get_tree().current_scene.get_node_or_null(^"Roads") as RoadNetwork
	if roads != null and (roads.is_on_road(spot) or roads.is_on_road(spot + Vector2(-150.0, 0.0))):
		return false
	return car.can_park_at(spot) and car.can_park_at(car_spot)

func _on_main_island(spot: Vector2) -> bool:
	if _main_island.is_empty():
		var path := get_tree().current_scene.get_node_or_null(MAIN_ISLAND_PATH) as Path2D
		if path == null or path.curve == null:
			return true
		_main_island = path.global_transform * path.curve.tessellate()
	return Geometry2D.is_point_in_polygon(spot, _main_island)

func _place_wreck_at(at: Vector2) -> void:
	Quests.set_note(QUEST, "%s%d,%d" % [CRASHED, roundi(at.x), roundi(at.y)])
	var grandpa := _grandpa()
	if grandpa != null:
		_ensure_wreck(grandpa)

## Where it came down, or Vector2.INF if it hasn't.
func _crash_spot() -> Vector2:
	var note := String(Quests.notes.get(QUEST, ""))
	if not note.begins_with(CRASHED):
		return Vector2.INF
	var xy := note.trim_prefix(CRASHED).split(",")
	return Vector2(float(xy[0]), float(xy[1])) if xy.size() == 2 else Vector2.INF

# --- Helpers --------------------------------------------------------------------------

func _ensure_pad(grandpa: GrandpaNpc) -> void:
	if is_instance_valid(_pad) or grandpa.get_parent() == null:
		return
	_pad = MiniHeliPad.new()
	_pad.name = "GrandpasHelicopter"
	_pad.on_board = _board
	_pad.visible = false
	grandpa.get_parent().add_child(_pad)
	_pad.global_position = StoryDirector.GRANDPA_SPOT + PAD_FROM_GRANDPA

func _ensure_wreck(grandpa: GrandpaNpc) -> void:
	var at := _crash_spot()
	if at == Vector2.INF or is_instance_valid(_wreck) or grandpa.get_parent() == null:
		return
	_wreck = MiniHeliWreck.new()
	_wreck.name = "GrandpasHelicopterWreck"
	grandpa.get_parent().add_child(_wreck)
	_wreck.global_position = at

func _grandpa() -> GrandpaNpc:
	var director := get_parent() as StoryDirector
	return director.grandpa() if director != null and is_instance_valid(director.grandpa()) else null
