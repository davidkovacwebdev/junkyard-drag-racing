class_name ExStory
extends Node
## Grandpa's hospital pranks, between "Beer Run" and "Pay Your Respects". Added by StoryDirector. Grandpa rides in the player's car the whole
## way (gone from his chair), talking from the passenger seat (CarChatter):
##
## - "Visiting Hours" (GrandpaExCutscene gives it): he points the way to the
##   hospital; there he has the player honk. The police come
##   (HospitalQuietZone hands them over here: ExPoliceExcuseCutscene), he
##   blames the car, and they let it go.
## - "Make Some Noise": off to the shop, where he hands over the money for the
##   loudest horn they sell (the Super Horn, the quest's item goal).
## - "Visiting Hours (Again)": back to the hospital to honk with it, and the
##   police beat the car until the lights go out (ExPoliceBeatingCutscene).
##   The player comes to in front of the house, beaten up; Grandpa's back in
##   his chair, and "Pay Your Respects" is next.
##
## Each leg's lines play once per visit to the map, so reloading mid-way
## hears them again; the money for the horn only once (Quests.notes).

const GROUP := &"ex_story"
const VISIT := &"ex_visit"
const HORN := &"ex_horn"
const REVENGE := &"ex_revenge"
const GRANDPA := preload("res://characters/grandpa.tres")
const EXCUSE_PATH := "res://cutscenes/ex_police_excuse.tres"
const BEATING_PATH := "res://cutscenes/ex_police_beating.tres"
const SHOP_PATH := ^"Sortables/Shop"
## How close to the hospital Grandpa starts shouting, and to the shop he
## starts plotting.
const HOSPITAL_RANGE := 950.0
const SHOP_RANGE := 650.0
## What he hands over for the horn (the Super Horn's price), once.
const HORN_MONEY := 150
const PAID := "paid"
## The Super Horn takes a while longer of honking before they come.
const REVENGE_HONK_SECONDS := 4.0

var _chatter: CarChatter
var _said := {}
var _hidden := false
var _grandpa_name := ""
var _busy := false

func _ready() -> void:
	add_to_group(GROUP)
	_chatter = CarChatter.new()
	add_child(_chatter)
	Quests.quest_added.connect(_on_quest_added)

func _on_quest_added(quest: QuestData) -> void:
	if quest.id in [VISIT, HORN, REVENGE]:
		Quests.set_tracked(quest)

func _riding() -> bool:
	return Quests.has_quest(VISIT) or Quests.has_quest(HORN) or Quests.has_quest(REVENGE)

func _process(_delta: float) -> void:
	var grandpa := _grandpa()
	if grandpa == null or GrandpaNpc.is_gone():
		return
	if not _busy:
		_hide_grandpa(grandpa, _riding())
	if not _riding() or Cutscenes.is_active():
		return
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var zone := _zone()
	if car == null:
		return
	var near_hospital := zone != null and car.global_position.distance_to(zone.global_position) <= HOSPITAL_RANGE
	if Quests.has_quest(VISIT):
		if _once(&"visit_intro"):
			_grandpa_says(VISIT, "Ok, go %s." % _direction(car, zone))
			_player_says(VISIT, "Where are we going?")
			_grandpa_says(VISIT, "Well, to the hospital.")
			_player_says(VISIT, "Oh, it's close by.")
		if near_hospital and _once(&"visit_honk"):
			_grandpa_says(VISIT, "AAAAAH!", &"grandpa_twitch")
			_player_says(VISIT, "What's wrong?")
			_grandpa_says(VISIT, "START HONKING!")
			_player_says(VISIT, "But gran..")
			_grandpa_says(VISIT, "START", &"grandpa_twitch")
			_grandpa_says(VISIT, "HONKING!")
	elif Quests.has_quest(HORN):
		if _once(&"horn_intro"):
			_grandpa_says(HORN, "Go to the store.")
			_player_says(HORN, "Okk?")
		var shop := get_tree().current_scene.get_node_or_null(SHOP_PATH) as Node2D
		if shop != null and car.global_position.distance_to(shop.global_position) <= SHOP_RANGE \
				and Quests.notes.get(HORN, "") != PAID:
			Quests.set_note(HORN, PAID)
			_grandpa_says(HORN, "Go get us a loud horn.")
			_player_says(HORN, "Grandpa, what are you planning?")
			_grandpa_says(HORN, "Here. Get the loudest one they've got.", &"cash_register")
			Inventory.money += HORN_MONEY
			_grandpa_says(HORN, "GO BUY IT!", &"grandpa_twitch")
			SaveSystem.save_game()
	elif Quests.has_quest(REVENGE):
		if _once(&"revenge_intro"):
			_grandpa_says(REVENGE, "Go to the hospital again, hehe.")
		if near_hospital and _once(&"revenge_honk"):
			_grandpa_says(REVENGE, "Start honking now, he he hee.", &"grandpa_cackle")

# --- The police (HospitalQuietZone hands them over) ---------------------------------

## Whether the honking outside the hospital is Grandpa's doing right now,
## and so this calls the police instead of the usual fine.
func takes_over_police() -> bool:
	return Quests.has_quest(VISIT) or Quests.has_quest(REVENGE)

## How many seconds of honking it takes before they come.
func honk_allowance(usual: float) -> float:
	return REVENGE_HONK_SECONDS if Quests.has_quest(REVENGE) else usual

func call_police() -> void:
	_busy = true
	_chatter.clear()
	if Quests.has_quest(VISIT):
		var excuse := ResourceLoader.load(EXCUSE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as ExPoliceExcuseCutscene
		if excuse != null:
			await Cutscenes.play(excuse)
		Quests.complete(VISIT)
	elif Quests.has_quest(REVENGE):
		var beating := ResourceLoader.load(BEATING_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as ExPoliceBeatingCutscene
		if beating != null:
			beating.grandpa = _grandpa()
			beating.wake_at = StoryDirector.OPENING_CAR_SPOT
			await Cutscenes.play(beating)
		Quests.complete(REVENGE)
	SaveSystem.save_game()
	_busy = false

# --- Helpers --------------------------------------------------------------------------

## Grandpa off with the player: not in his chair, nothing to talk to.
func _hide_grandpa(grandpa: GrandpaNpc, hide: bool) -> void:
	if hide == _hidden:
		return
	_hidden = hide
	if hide:
		_grandpa_name = grandpa.display_name
		grandpa.display_name = ""
	else:
		grandpa.display_name = _grandpa_name if not _grandpa_name.is_empty() else "Grandpa"
	grandpa.visible = not hide
	for child in grandpa.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", hide)

func _grandpa_says(quest: StringName, line: String, sound: StringName = &"") -> void:
	_chatter.say("Grandpa", GRANDPA, line, sound)
	Quests.log_line(quest, "Grandpa", line)

func _player_says(quest: StringName, line: String) -> void:
	_chatter.say(PlayerProfile.display_name(), PlayerProfile.character, line)
	Quests.log_line(quest, PlayerProfile.display_name(), line)

func _once(key: StringName) -> bool:
	if _said.has(key):
		return false
	_said[key] = true
	return true

## Which way the hospital is from the car, as he'd say it.
func _direction(car: Node2D, zone: Node2D) -> String:
	if zone == null:
		return "right"
	var way := zone.global_position - car.global_position
	if absf(way.x) >= absf(way.y):
		return "right" if way.x > 0.0 else "left"
	return "down" if way.y > 0.0 else "up"

func _zone() -> Node2D:
	var zones := get_tree().current_scene.find_children("*", "HospitalQuietZone", true, false)
	return zones[0] as Node2D if not zones.is_empty() else null

func _grandpa() -> GrandpaNpc:
	var director := get_parent() as StoryDirector
	return director.grandpa() if director != null and is_instance_valid(director.grandpa()) else null
