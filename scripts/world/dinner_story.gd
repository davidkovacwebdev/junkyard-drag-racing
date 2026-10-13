class_name DinnerStory
extends Node
## Grandpa's dinner run, between "Gone Fishin'" and "Make Me Proud". Added
## by StoryDirector.
##
## - "Fish Supper" (GrandpaDinnerCutscene gives it): Grandpa wheels himself
##   off along the roads (RoadRoute) to the fishing pier, and the player
##   follows. He stays solid on the way, like the garbage truck: ram him and
##   he lets you hear about it (GrandpaNpc.car_rammed()). He waits whenever they fall too far behind. At the pier,
##   DynamiteFishingCutscene: dynamite, floating fish, the net, sirens.
## - "Catch and Run" follows: he races home the same way, police lights
##   flashing red and blue over the screen (PoliceLights) and sirens wailing
##   off somewhere, and it's done when the two of them are back at his spot.
##
## Reloading mid-way starts the leg over: from his spot on the way there,
## from the pier on the way back.

const SUPPER := &"fish_supper"
const ESCAPE := &"fish_escape"
const PIER_PATH := ^"Sortables/FishingPort/Pier"
const SCENE_PATH := "res://cutscenes/dynamite_fishing.tres"
## Where Grandpa stops at the pier, and where his dynamite lands, from the
## pier's start (its deck runs right, out over the water).
const PIER_STOP := Vector2(40.0, 0.0)
const DYNAMITE_SPLASH := Vector2(330.0, 150.0)
## Wheelchair speed, there and (in a hurry) back.
const SPEED := 300.0
const ESCAPE_SPEED := 360.0
## Grandpa sets off once the car is this close, and waits whenever it's
## further than WAIT_RANGE behind.
const START_RANGE := 700.0
const WAIT_RANGE := 750.0
## The pier scene starts, and the run home ends, with the car this close.
const ARRIVE_RANGE := 600.0
const NAG_SECONDS := 7.0
const SQUEAK_SECONDS := 1.3
const SIREN_SECONDS := Vector2(2.2, 3.4)
const NAG_LINES: Array[String] = ["Keep up, lad!", "Don't dawdle!", "My dinner's gettin' away!"]
const RUN_NAG_LINES: Array[String] = ["FASTER!", "They're right behind us!", "Move it, lad!"]
const HOME_LINE := "Phew! Dinner's on me, lad."

var _route := PackedVector2Array()
var _leg := 0
var _riding := false
var _speed := SPEED
var _nag := 0.0
var _squeak := 0.0
var _siren := 0.0
var _lights: PoliceLights = null
var _busy := false

func _ready() -> void:
	Quests.quest_added.connect(_on_quest_added)

## Each leg is tracked as it lands, so the GPS points at Grandpa.
func _on_quest_added(quest: QuestData) -> void:
	if quest.id == SUPPER or quest.id == ESCAPE:
		Quests.set_tracked(quest)

func _process(delta: float) -> void:
	var grandpa := _grandpa()
	if grandpa == null or GrandpaNpc.is_gone() or _busy:
		return
	var escaping := Quests.has_quest(ESCAPE)
	_update_lights(escaping, delta)
	if not Quests.has_quest(SUPPER) and not escaping:
		return
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null or Cutscenes.is_active():
		return
	if not _riding:
		if escaping and _route.is_empty():
			# Back from a reload mid-run: he's at the pier.
			grandpa.global_position = _pier_stop()
		if car.global_position.distance_to(grandpa.global_position) <= START_RANGE:
			_set_off(grandpa, _home() if escaping else _pier_stop(), ESCAPE_SPEED if escaping else SPEED)
		return
	_ride(grandpa, car, delta, escaping)

func _set_off(grandpa: GrandpaNpc, to: Vector2, speed: float) -> void:
	var roads := get_tree().current_scene.get_node_or_null(^"Roads") as RoadNetwork
	_route = RoadRoute.find(roads, grandpa.global_position, to)
	_leg = 1
	_speed = speed
	_riding = true

func _ride(grandpa: GrandpaNpc, car: Node2D, delta: float, escaping: bool) -> void:
	if car.global_position.distance_to(grandpa.global_position) > WAIT_RANGE:
		_nag -= delta
		if _nag <= 0.0:
			_nag = NAG_SECONDS
			var lines := RUN_NAG_LINES if escaping else NAG_LINES
			Pickup.spawn_float_text(grandpa.get_parent(), grandpa.global_position + Vector2(0.0, -150.0),
					lines[randi() % lines.size()])
		return
	var step := _speed * delta
	while step > 0.0 and _leg < _route.size():
		var target := _route[_leg]
		var to_target := target - grandpa.global_position
		if to_target.length() <= step:
			grandpa.global_position = target
			step -= to_target.length()
			_leg += 1
		else:
			grandpa.global_position += to_target.normalized() * step
			if absf(to_target.x) > 1.0:
				grandpa.actor.face(to_target.x > 0.0)
			step = 0.0
	_squeak -= delta
	if _squeak <= 0.0:
		_squeak = SQUEAK_SECONDS
		Sfx.play_at(&"wheelchair_squeak", grandpa.global_position, -10.0, 0.1)
	if _leg >= _route.size() and car.global_position.distance_to(grandpa.global_position) <= ARRIVE_RANGE:
		_riding = false
		_route = PackedVector2Array()
		if escaping:
			_home_safe(grandpa)
		else:
			_at_the_pier(grandpa)

func _at_the_pier(grandpa: GrandpaNpc) -> void:
	_busy = true
	var scene := ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as DynamiteFishingCutscene
	if scene != null:
		scene.grandpa = grandpa
		scene.water_at = _pier() + DYNAMITE_SPLASH
		await Cutscenes.play_once(scene)
	Quests.complete(SUPPER)
	SaveSystem.save_game()
	_busy = false

func _home_safe(grandpa: GrandpaNpc) -> void:
	grandpa.global_position = _home()
	grandpa.actor.face(grandpa.facing_right)
	Sfx.play_at(&"grandpa_laugh", grandpa.global_position, -6.0, 0.0)
	Pickup.spawn_float_text(grandpa.get_parent(), grandpa.global_position + Vector2(0.0, -150.0), HOME_LINE)
	Quests.complete(ESCAPE)
	SaveSystem.save_game()

## Red and blue washing over the screen, and sirens off somewhere, while
## they're on the run.
func _update_lights(on: bool, delta: float) -> void:
	if on and _lights == null:
		_lights = PoliceLights.new()
		add_child(_lights)
	elif not on and _lights != null:
		_lights.queue_free()
		_lights = null
	if _lights == null:
		return
	_lights.visible = not Cutscenes.is_active()
	_siren -= delta
	if _siren <= 0.0 and not Cutscenes.is_active():
		_siren = randf_range(SIREN_SECONDS.x, SIREN_SECONDS.y)
		Sfx.play(&"siren_whoop", -16.0, 0.08)

func _grandpa() -> GrandpaNpc:
	var director := get_parent() as StoryDirector
	return director.grandpa() if director != null and is_instance_valid(director.grandpa()) else null

func _pier() -> Vector2:
	var pier := get_tree().current_scene.get_node_or_null(PIER_PATH) as Node2D
	return pier.global_position if pier != null else Vector2(9470.0, 2440.0)

func _pier_stop() -> Vector2:
	return _pier() + PIER_STOP

func _home() -> Vector2:
	return StoryDirector.GRANDPA_SPOT
