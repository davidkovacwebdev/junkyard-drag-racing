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
##   plays DigSiteCutscene, which finishes it; "Metal Head" follows (ask at
##   the junkyard, ScrapDealer), then "Grandpa's Shed" (the garage,
##   GrandpasGarage) and "Juice" (batteries), each tracked as it lands.
## - The shop's out of batteries (Shop), which finishes "Juice"; "Scrap
##   Juice" (ask at the junkyard, ScrapDealer) follows, then "Fish It Out"
##   (the toy car motor, CranePen) and, a day later, "Charged Up" (pick the
##   detector up at the counter).
## - "Beep Beep": using the working metal detector from the trunk switches
##   it on and off (DetectorSweep). The treasure is buried a random way off
##   the X (rolled once, kept in Quests.notes); pressing E right over it
##   plays MarkSpotCutscene, which sticks Grandpa's fake leg in there
##   (TreasureMark), and finishes the quest.
## - "Heavy Machinery" (ask at the junkyard for something to dig with,
##   DiggerRevealCutscene) puts the player in the yard's digger for "Dig
##   It" (PlayerCar, DiggerRig). Three scoops (F) make a hole (DigHole); a
##   full hole by the leg turns up a treasure chest, which finishes it. Then
##   "Finders Keepers": E at the chest (ChestPickup) puts it in the trunk;
##   "Show and Tell": driving into the junkyard with it opens it
##   (ChestOpeningCutscene, JunkyardStory). Back out in the world the "more
##   quests soon" card (ComingSoonCutscene) plays: the end of the story so
##   far.

const RUMORS := &"treasure_rumors"
const MEETUP := preload("res://quests/chad_meetup.tres")
const VISIT := preload("res://quests/smithy_visit.tres")
const NIGHT_DIGGER := &"night_digger"
const BEGGAR := &"beggar_info"
const RAID_PATH := "res://cutscenes/smithy_raid.tres"
const DIG_SITE := preload("res://quests/dig_site.tres")
const DIG_SITE_PATH := "res://cutscenes/dig_site.tres"
const COMING_SOON_PATH := "res://cutscenes/coming_soon.tres"
const METAL_HEAD := &"metal_head"
const SHED := &"grandpas_shed"
const BATTERIES := &"batteries"
const JUNKYARD_BATTERIES := &"junkyard_batteries"
const TOY_MOTOR := &"toy_motor"
const DETECTOR_PICKUP := &"detector_pickup"
const SWEEP := &"treasure_sweep"
const DIG_GEAR := &"dig_gear"
const TREASURE_DIG := &"treasure_dig"
const CHEST_PICKUP := &"chest_pickup"
const CHEST_JUNKYARD := &"chest_junkyard"
const CHEST_ITEM := &"treasure_chest"
## DiggerRig tells this group about every scoop (`on_hole_dug()`).
const GROUP := &"treasure_story"
## How near the leg a full hole has to be to hit the chest.
const CHEST_RANGE := 80.0
## The card's own id at the end of the story so far, so it shows even though
## the one after "The Dig Site" (on older saves) already has.
const STORY_END := &"coming_soon_chest"
## The metal detector's use_effect, and how far off the X the treasure can
## be buried (rolled once per save).
const DETECTOR_EFFECT := &"metal_detector"
const MARK_SCENE_PATH := "res://cutscenes/mark_spot.tres"
const TREASURE_OFFSET := Vector2(130.0, 340.0)
## How close the car has to get to the X for the dig site scene.
const DIG_SITE_RANGE := 450.0
## Chad said two days.
const MEETUP_DAYS := 2
## How close the car has to get to Gus for the raid to start.
const RAID_RANGE := 520.0
const CHECK_INTERVAL := 0.5

var _timer := 0.0
var _sweep: DetectorSweep = null

func _ready() -> void:
	add_to_group(GROUP)
	Quests.quest_added.connect(_on_quest_added)
	Inventory.set_use_check(DETECTOR_EFFECT, _detector_blocked_reason)
	Inventory.item_used.connect(_on_item_used)
	if Quests.is_complete(TREASURE_DIG):
		_place_found.call_deferred()
	elif Quests.is_complete(SWEEP):
		_place_mark.call_deferred()

func _exit_tree() -> void:
	Inventory.set_use_check(DETECTOR_EFFECT, Callable())
	if Inventory.item_used.is_connected(_on_item_used):
		Inventory.item_used.disconnect(_on_item_used)

func _on_quest_added(quest: QuestData) -> void:
	if quest.id in [MEETUP.id, DIG_SITE.id, METAL_HEAD, SHED, BATTERIES, JUNKYARD_BATTERIES,
			TOY_MOTOR, DETECTOR_PICKUP, SWEEP, DIG_GEAR, TREASURE_DIG, CHEST_PICKUP, CHEST_JUNKYARD]:
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
	if Quests.is_complete(CHEST_JUNKYARD) and not Cutscenes.has_seen(STORY_END) and not Cutscenes.is_active() \
			and get_tree().get_first_node_in_group(PlayerCar.GROUP) != null:
		var coming_soon := ResourceLoader.load(COMING_SOON_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as ComingSoonCutscene
		if coming_soon != null:
			coming_soon.id = STORY_END
			Cutscenes.play_once(coming_soon)

# --- The metal detector ("Beep Beep") ------------------------------------------------

func _detector_blocked_reason(_item: ItemData) -> String:
	if Cutscenes.is_active() or get_tree().get_first_node_in_group(PlayerCar.GROUP) == null:
		return "Not now."
	return ""

## Using it from the trunk switches it on, or off again.
func _on_item_used(item: ItemData) -> void:
	if item.use_effect != DETECTOR_EFFECT:
		return
	if is_instance_valid(_sweep):
		_switch_off()
		return
	Sfx.play(&"detector_beep", -6.0, 0.0)
	_sweep = DetectorSweep.new()
	_sweep.has_target = Quests.has_quest(SWEEP)
	if _sweep.has_target:
		_sweep.target = treasure_spot()
	_sweep.marked.connect(_on_marked)
	add_child(_sweep)

func _switch_off() -> void:
	Sfx.play(&"phone_beep", -8.0, 0.0).pitch_scale *= 0.7
	_sweep.queue_free()
	_sweep = null

## Where the treasure really is: a random way off the X, on dry land and
## off the road, rolled the first time it's asked for and kept with the
## quest's notes.
static func treasure_spot() -> Vector2:
	var saved := String(Quests.notes.get(SWEEP, ""))
	var parts := saved.split(",")
	if parts.size() == 2:
		return Vector2(float(parts[0]), float(parts[1]))
	var tree := Engine.get_main_loop() as SceneTree
	var car := tree.get_first_node_in_group(PlayerCar.GROUP) as PlayerCar if tree != null else null
	var terrain := car.get_terrain() if car != null else null
	var roads := car.get_road_network() if car != null else null
	var spot := TreasureDigSpot.SPOT
	for attempt in 40:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(TREASURE_OFFSET.x, TREASURE_OFFSET.y)
		spot = (TreasureDigSpot.SPOT + offset).round()
		var wet := terrain != null and terrain.is_in_water(terrain.to_local(spot))
		var paved := roads != null and roads.is_on_road(spot)
		if not wet and not paved:
			break
	Quests.set_note(SWEEP, "%d,%d" % [spot.x, spot.y])
	return spot

## E right over it: the stake goes in, the detector goes quiet, and the
## quest is done.
func _on_marked(spot: Vector2) -> void:
	_switch_off()
	var scene := ResourceLoader.load(MARK_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as MarkSpotCutscene
	if scene != null:
		scene.spot = spot
		await Cutscenes.play(scene)
	_place_mark()
	Quests.complete(SWEEP)
	SaveSystem.save_game()

func _place_mark() -> void:
	TreasureMark.place(_sortables(), treasure_spot())

## The hole the chest came out of, with the chest still in it until it's
## been picked up.
func _place_found() -> void:
	var waiting := Quests.has_quest(CHEST_PICKUP) and not Inventory.has_item(CHEST_ITEM)
	var hole := DigHole.place_found(_sortables(), treasure_spot(), waiting)
	if waiting and hole != null:
		_add_chest_pickup(hole)

func _add_chest_pickup(hole: DigHole) -> void:
	var pickup := ChestPickup.new()
	pickup.hole = hole
	pickup.position = hole.position
	hole.get_parent().add_child(pickup)

func _sortables() -> Node:
	return get_tree().current_scene.get_node_or_null(^"Sortables") if get_tree().current_scene != null else null

# --- Digging ("Dig It") -----------------------------------------------------------

## A scoop from the digger: a full hole by the leg has the chest in it.
func on_hole_dug(hole: DigHole) -> void:
	if not Quests.has_quest(TREASURE_DIG) or not hole.is_full() or hole.has_chest:
		return
	if hole.global_position.distance_to(treasure_spot()) > CHEST_RANGE:
		return
	TreasureMark.remove(_sortables())
	hole.reveal_chest()
	_add_chest_pickup(hole)
	Sfx.play(&"wood_clonk", -4.0, 0.0)
	Sfx.play(&"wink_ting", -2.0, 0.0)
	Pickup.spawn_float_text(get_parent(), hole.global_position + Vector2(0.0, -90.0), "A treasure chest!")
	Quests.complete(TREASURE_DIG)
	SaveSystem.save_game()

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
