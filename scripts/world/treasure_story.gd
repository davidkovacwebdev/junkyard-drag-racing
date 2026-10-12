class_name TreasureStory
extends Node
## The Junkyard Treasure story after "Dig Deeper", from Chad's "meet me in two
## days" on. Added by StoryDirector.
##
## - Once "Ask Around" is on, "Weekend's Over" (meet Chad at his house) lands
##   in the log two in-game days later. Saves that were already asking around
##   start counting the first time the map loads. When it lands it's tracked,
##   so Chad lights up on the minimap and the GPS points at him.
## - Gus is "caught" once he's confessed, either after the player rams his
##   pickup at night (NightDiggerCutscene) or when Chad and the player call on
##   him at the forge (SmithyRaidCutscene). From then on he stays home and
##   "Graveyard Shift" is done.
## - Once "Ask Around" is solved (reported to Chad), the beggar's "Wet His
##   Whistle" is dropped from the log if it's still open: nothing left for
##   him to tell.
## - During "Strike While It's Hot", driving up to the Scrap Forge plays the
##   raid.
## - Once Gus is caught and the player has reported to Chad, "The Dig Site"
##   is handed out and tracked (the X glows on the minimap). Reaching the X
##   plays DigSiteCutscene, which finishes it, and then the "more quests
##   soon" card (ComingSoonCutscene): the end of the story so far.

const RUMORS := &"treasure_rumors"
const MEETUP := preload("res://quests/chad_meetup.tres")
const VISIT := preload("res://quests/smithy_visit.tres")
const NIGHT_DIGGER := &"night_digger"
const BEGGAR := &"beggar_info"
const RAID_PATH := "res://cutscenes/smithy_raid.tres"
const DIG_SITE := preload("res://quests/dig_site.tres")
const DIG_SITE_PATH := "res://cutscenes/dig_site.tres"
const COMING_SOON_PATH := "res://cutscenes/coming_soon.tres"
## How close the car has to get to the X for the dig site scene.
const DIG_SITE_RANGE := 450.0
## Chad said two days.
const MEETUP_DAYS := 2
## How close the car has to get to Gus for the raid to start.
const RAID_RANGE := 520.0
const CHECK_INTERVAL := 0.5

var _timer := 0.0

func _ready() -> void:
	Quests.quest_added.connect(_on_quest_added)

func _on_quest_added(quest: QuestData) -> void:
	if quest.id == MEETUP.id or quest.id == DIG_SITE.id:
		Quests.set_tracked(quest)

## Whether Gus has owned up to planting the fakes and marked the dig spot.
static func gus_caught() -> bool:
	return Cutscenes.has_seen(NightDiggerCutscene.ID) or Cutscenes.has_seen(SmithyRaidCutscene.ID)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	if Quests.has_quest(RUMORS) and not Quests.has_quest(MEETUP.id) \
			and not Quests.is_complete(MEETUP.id) and not Quests.is_waiting(MEETUP.id):
		Quests.give_later(MEETUP, MEETUP_DAYS)
	if gus_caught() and Quests.has_quest(NIGHT_DIGGER) and not Cutscenes.is_active():
		# Caught some other way, or the beggar sent the player after him late.
		Quests.complete(NIGHT_DIGGER)
	if Quests.is_complete(RUMORS) and Quests.has_quest(BEGGAR):
		Quests.rewind([BEGGAR], null)
	if Quests.has_quest(VISIT.id) and not Cutscenes.is_active():
		_check_raid()
	if gus_caught() and Quests.is_complete(MEETUP.id) and not Quests.has_quest(VISIT.id) \
			and not Quests.has_quest(DIG_SITE.id) and not Quests.is_complete(DIG_SITE.id):
		Quests.give(DIG_SITE)
	if Quests.has_quest(DIG_SITE.id) and not Cutscenes.is_active():
		_check_dig_site()

func _check_dig_site() -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null or car.global_position.distance_to(TreasureDigSpot.SPOT) > DIG_SITE_RANGE:
		return
	var scene := ResourceLoader.load(DIG_SITE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as DigSiteCutscene
	if scene == null:
		return
	await Cutscenes.play_once(scene)
	Quests.complete(DIG_SITE.id)
	SaveSystem.save_game()
	var coming_soon := load(COMING_SOON_PATH) as ComingSoonCutscene
	if coming_soon != null:
		Cutscenes.play_once(coming_soon)

func _check_raid() -> void:
	var gus := get_tree().get_first_node_in_group(ForgeSmith.GROUP) as ForgeSmith
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if gus == null or car == null or gus.is_away():
		return
	if car.global_position.distance_to(gus.global_position) > RAID_RANGE:
		return
	var raid := ResourceLoader.load(RAID_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as SmithyRaidCutscene
	if raid == null:
		return
	raid.npc_rig = gus.get_node_or_null("Character") as CharacterRig
	await Cutscenes.play_once(raid)
	Quests.complete(VISIT.id)
	SaveSystem.save_game()
