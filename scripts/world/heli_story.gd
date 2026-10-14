class_name HeliStory
extends Node
## "Up, Up and Away", between "Visiting Hours (Again)" and "Pay Your
## Respects". Added by StoryDirector. GrandpaFlyCutscene gives it; Grandpa
## rides in the player's car (gone from his chair), talking from the
## passenger seat (CarChatter), the way ExStory has him:
##
## - On the way he sends the player to "the south peninsula", and then, once
##   they've argued about it, to the crashed helicopter, which is on the map
##   for the quest (a HELICOPTER MinimapMarker, "Helicopter Crash Site").
## - There, HeliCrashSiteCutscene: he whacks the wreck with his wrench, twice,
##   and has the player ram it 10 times with the car. CrashedHelicopter hands
##   the rams over (`helicopter_rammed()`); the tenth bursts the helicopter
##   engine and the tail rotor out of it as orbs for the trunk.
## - Both in the trunk, the quest is ready. Driving up to his spot at home
##   hands it in: GrandpaNpc plays GrandpaHeliHomeCutscene and takes them.
##
## Where it's got to is in Quests.notes (SITE once the crash site scene has
## played) and the rams in Quests.counts, so a reload picks up where it was;
## the orbs come back if they were never picked up. His lines play once per
## visit to the map.

const GROUP := &"heli_story"
const QUEST := &"heli_parts"
const GRANDPA := preload("res://characters/grandpa.tres")
const ENGINE := preload("res://items/heli_engine.tres")
const ROTOR := preload("res://items/tail_rotor.tres")
const SCENE_PATH := "res://cutscenes/heli_crash_site.tres"
const PLACE_NAME := "Helicopter Crash Site"
## Quests.notes value once the crash site scene has played.
const SITE := "site"
const HITS := 10
## How close the car gets to the wreck before the scene, and to his spot at
## home before he hands the quest in.
const SITE_RANGE := 650.0
const HOME_RANGE := 420.0
## A hard ram only counts once in this long.
const RAM_COOLDOWN_MS := 600
const RAM_TEXT_LIFT := 190.0
## Where the parts fly out from and land, from the wreck's origin.
const BURST_FROM := Vector2(40.0, -110.0)
const ENGINE_LANDS := Vector2(-60.0, 150.0)
const ROTOR_LANDS := Vector2(110.0, 170.0)
## What he shouts from the passenger seat on some of the rams.
const RAM_LINES: Array[String] = ["WHEEE!", "AGAIN!", "Harder, lad! My teeth are still in!",
		"That's the spirit!", "Hehehe! My hip!", "Is that all you got?"]

var _chatter: CarChatter
var _said := {}
var _hidden := false
var _grandpa_name := ""
var _busy := false
var _marker: MinimapMarker = null
var _last_ram_ms := -RAM_COOLDOWN_MS
var _orbs: Array[ItemPickup] = []

func _ready() -> void:
	add_to_group(GROUP)
	_chatter = CarChatter.new()
	add_child(_chatter)
	Quests.quest_added.connect(_on_quest_added)

func _on_quest_added(quest: QuestData) -> void:
	if quest.id == QUEST:
		Quests.set_tracked(quest)

func _process(_delta: float) -> void:
	var grandpa := _grandpa()
	if grandpa == null or GrandpaNpc.is_gone():
		return
	var riding := Quests.has_quest(QUEST)
	_update_marker(riding and not Quests.is_ready(QUEST))
	if _busy or Cutscenes.is_active():
		return
	_hide_grandpa(grandpa, riding)
	if not riding:
		return
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var heli := _helicopter()
	if car == null:
		return
	if Quests.is_ready(QUEST):
		if _once(&"home_intro"):
			_grandpa_says("Home, lad! Hehehe, careful with my propeller.", &"grandpa_cackle")
		if car.global_position.distance_to(grandpa.global_position) <= HOME_RANGE:
			_chatter.clear()
			grandpa.interact(car)
		return
	if Quests.notes.get(QUEST, "") != SITE:
		if _once(&"intro"):
			_grandpa_says("Ok, go to the south peninsula.")
			_player_says("South peninsula?")
			_grandpa_says("You don't know what a peninsula is?")
			_player_says("I do, but this is a small map. Funny, you calling it a peninsula.")
			_grandpa_says("Just go to the helicopter crash site.")
		if heli != null and car.global_position.distance_to(heli.global_position) <= SITE_RANGE:
			_at_the_site(grandpa, heli)
		return
	if Quests.count_of(QUEST) >= HITS:
		_restore_orbs(heli)
		if _once(&"grab"):
			_grandpa_says("Grab 'em! In the trunk, both of 'em!")
	elif _once(&"ram_intro"):
		_grandpa_says("Well? Ram it! Ten times!")

func _at_the_site(grandpa: GrandpaNpc, heli: CrashedHelicopter) -> void:
	_busy = true
	_chatter.clear()
	var scene := ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as HeliCrashSiteCutscene
	if scene != null:
		scene.grandpa = grandpa
		scene.helicopter = heli
		await Cutscenes.play(scene)
	Quests.set_note(QUEST, SITE)
	_said[&"ram_intro"] = true
	SaveSystem.save_game()
	_busy = false

# --- The rams (CrashedHelicopter hands them over) ---------------------------------

## A hard hit on the wreck: one more toward the ten while he's asked for them,
## with a "3 / 10" over it; the tenth bursts the parts out.
func helicopter_rammed(heli: CrashedHelicopter, car: Node, _impact_speed: float) -> void:
	if not Quests.has_quest(QUEST) or Quests.notes.get(QUEST, "") != SITE \
			or Quests.count_of(QUEST) >= HITS or Cutscenes.is_active():
		return
	var now := Time.get_ticks_msec()
	if now - _last_ram_ms < RAM_COOLDOWN_MS:
		return
	_last_ram_ms = now
	var hits := Quests.add_count(QUEST)
	Sfx.play_at(&"car_whack", heli.global_position, -4.0, 0.08)
	heli.shudder()
	var text_at := (car as Node2D).global_position + Vector2(0.0, -RAM_TEXT_LIFT) if car is Node2D \
			else heli.global_position + Vector2(0.0, -RAM_TEXT_LIFT)
	if hits < HITS:
		Pickup.spawn_callout(heli.get_parent(), text_at, "%d / %d" % [hits, HITS])
		if hits == 1 or randf() < 0.35:
			if not _chatter.is_talking():
				_grandpa_says(RAM_LINES[randi() % RAM_LINES.size()], &"grandpa_twitch")
		return
	Pickup.spawn_callout(heli.get_parent(), text_at, "Something came loose!")
	Sfx.play_at(&"heli_parts_pop", heli.global_position, -2.0, 0.0)
	_burst(heli, 0.55)
	_chatter.clear()
	_said[&"grab"] = true
	_grandpa_says("THERE! Hehehe! An engine AND a propeller!", &"grandpa_cackle")
	_grandpa_says("Grab 'em! In the trunk, both of 'em!")
	SaveSystem.save_game()

## The engine and the tail rotor flung out of the wreck onto the sand, for
## whichever of them isn't in the trunk yet. `seconds` is the flight.
func _burst(heli: CrashedHelicopter, seconds: float) -> void:
	var from := heli.global_position + BURST_FROM
	for pair: Array in [[ENGINE, ENGINE_LANDS], [ROTOR, ROTOR_LANDS]]:
		var item: ItemData = pair[0]
		if Inventory.has_item(item.id) or _has_orb(item):
			continue
		var orb := ItemPickup.new()
		orb.configure(item)
		orb.persistent = true
		heli.get_parent().add_child(orb)
		orb.launch(from, heli.global_position + pair[1], 120.0, seconds, 0.1 * _orbs.size())
		_orbs.append(orb)

## After a reload, the parts lie where they landed, unless already taken.
func _restore_orbs(heli: CrashedHelicopter) -> void:
	if heli != null:
		_burst(heli, 0.01)

func _has_orb(item: ItemData) -> bool:
	# filter() hands back an untyped Array; assign() keeps `_orbs` typed.
	_orbs.assign(_orbs.filter(func(orb) -> bool: return is_instance_valid(orb)))
	for orb in _orbs:
		if orb.item == item:
			return true
	return false

# --- Helpers --------------------------------------------------------------------------

## The wreck on the map, glowing as the quest's place, until the parts are in.
func _update_marker(wanted: bool) -> void:
	if wanted and _marker == null:
		var heli := _helicopter()
		if heli == null:
			return
		_marker = MinimapMarker.new()
		_marker.kind = MinimapMarker.Kind.HELICOPTER
		_marker.place_name_override = PLACE_NAME
		heli.add_child(_marker)
	elif not wanted and _marker != null:
		_marker.remove_from_group(MinimapMarker.GROUP)
		_marker.queue_free()
		_marker = null

## Grandpa off with the player: not in his chair, nothing to talk to. Once
## the parts are in, his name's back so the map can point home at him.
func _hide_grandpa(grandpa: GrandpaNpc, hide: bool) -> void:
	if hide and not _hidden:
		_hidden = true
		_grandpa_name = grandpa.display_name if not grandpa.display_name.is_empty() else "Grandpa"
		grandpa.visible = false
		_set_solid(grandpa, false)
	elif not hide and _hidden:
		_hidden = false
		grandpa.visible = true
		_set_solid(grandpa, true)
	if _hidden:
		grandpa.display_name = _grandpa_name if Quests.is_ready(QUEST) else ""
	elif grandpa.display_name.is_empty() and not _grandpa_name.is_empty():
		grandpa.display_name = _grandpa_name

static func _set_solid(grandpa: GrandpaNpc, solid: bool) -> void:
	for child in grandpa.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not solid)

func _grandpa_says(line: String, sound: StringName = &"") -> void:
	_chatter.say("Grandpa", GRANDPA, line, sound)
	Quests.log_line(QUEST, "Grandpa", line)

func _player_says(line: String) -> void:
	_chatter.say(PlayerProfile.display_name(), PlayerProfile.character, line)
	Quests.log_line(QUEST, PlayerProfile.display_name(), line)

func _once(key: StringName) -> bool:
	if _said.has(key):
		return false
	_said[key] = true
	return true

func _helicopter() -> CrashedHelicopter:
	return get_tree().get_first_node_in_group(CrashedHelicopter.GROUP) as CrashedHelicopter

func _grandpa() -> GrandpaNpc:
	var director := get_parent() as StoryDirector
	return director.grandpa() if director != null and is_instance_valid(director.grandpa()) else null
