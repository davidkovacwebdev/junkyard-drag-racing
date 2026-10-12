@tool
class_name GrandpasGarage
extends ComposedBuilding
## The garage by Grandpa's spot: E drives in to the garage as usual. Two of
## the story's quests happen here instead:
##   - "Grandpa?": E plays the scene where the player looks for him
##     (GrandpaGoneCutscene) and finishes the quest once it's over;
##   - "Under the Mattress": E plays the search for the old nickel
##     (GrandpaMattressCutscene) and puts it in the trunk, which finishes
##     that quest (its item goal). With the trunk full the nickel stays put
##     and the player can come back for it.
##
## Every garage bay the player buys (Inventory.garage_bays_bought) shows up as
## another little shed in a row to the left of the house, each one another
## way in to the same garage.

const QUEST_ID := &"grandpa_missing"
const SCENE_PATH := "res://cutscenes/grandpa_gone.tres"
const MATTRESS_QUEST := &"mattress_nickel"
const MATTRESS_SCENE_PATH := "res://cutscenes/grandpa_mattress.tres"
const NICKEL := preload("res://items/old_nickel.tres")
const BAY_DATA := preload("res://buildings/player_garage_bay.tres")
const BUILDING_SCENE := preload("res://scenes/world/composed_building.tscn")
## Every clear spot a bay can go up on, as its ground point from the house's
## own. Checked against Grandpa, Tiger, the smoker, the driveway and the pines.
## Each save shuffles these with its
## Inventory.garage_layout_seed and fills them in that order, so buying a bay
## never moves the ones already standing.
const BAY_SPOTS: Array[Vector2] = [
	Vector2(-215.0, -70.0), Vector2(-330.0, -35.0), Vector2(-410.0, -130.0),
	Vector2(-370.0, 200.0), Vector2(-460.0, 150.0), Vector2(-660.0, 170.0),
]
## Each bay is a half-size shed like the one on the right, give or take.
const BAY_SCALE_MIN := 0.45
const BAY_SCALE_MAX := 0.55

func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		_build_bays.call_deferred()

func _build_bays() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Inventory.garage_layout_seed
	var spots := BAY_SPOTS.duplicate()
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Vector2 = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var scales: Array[float] = []
	for i in spots.size():
		scales.append(rng.randf_range(BAY_SCALE_MIN, BAY_SCALE_MAX))
	for i in mini(Inventory.garage_bays_bought(), spots.size()):
		_add_bay(position + spots[i], scales[i])

## One more shed, standing on `ground` (world space, next to this house).
func _add_bay(ground: Vector2, bay_scale: float) -> void:
	var bay := BUILDING_SCENE.instantiate() as ComposedBuilding
	bay.building_data = BAY_DATA
	bay.display_name = display_name
	bay.interior_scene = interior_scene
	bay.scale = Vector2.ONE * bay_scale
	# A ComposedBuilding drops itself by half its footprint onto its ground
	# line once it's in the tree, so it's placed that much higher.
	bay.position = ground - Vector2(0.0, BuildingAssembler.get_footprint_size(BAY_DATA).y / 2.0)
	get_parent().add_child(bay)

func get_interact_prompt() -> String:
	if _searching():
		return "%s: Press E to look for Grandpa" % display_name
	if _mattress_waiting():
		return "%s: Press E to look under Grandpa's mattress" % display_name
	return ""

## Called by PlayerCar on E or a click.
func interact(_actor: Node = null) -> void:
	if _searching():
		_look_for_grandpa()
		return
	if _mattress_waiting():
		_look_under_mattress()
		return
	if interior_scene != null:
		Sfx.play(&"door_close", -4.0)
		SceneLoader.change_scene_packed(interior_scene)

func _searching() -> bool:
	return Quests.has_quest(QUEST_ID) and not Cutscenes.is_active()

func _mattress_waiting() -> bool:
	return Quests.has_quest(MATTRESS_QUEST) and not Inventory.has_item(NICKEL.id) \
			and not Cutscenes.is_active()

func _look_for_grandpa() -> void:
	# He's gone before the player gets out, even if they were parked here
	# when the quest landed.
	var director := get_tree().get_first_node_in_group(StoryDirector.GROUP) as StoryDirector
	if director != null and director.grandpa() != null:
		director.grandpa().vanish()
	var scene := ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as GrandpaGoneCutscene
	if scene != null:
		scene.garage = self
		await Cutscenes.play(scene)
	Music.hush(false)
	Quests.complete(QUEST_ID)
	SaveSystem.save_game()

func _look_under_mattress() -> void:
	if Inventory.is_trunk_full():
		Sfx.play(&"denied", -6.0, 0.0)
		Pickup.spawn_float_text(get_parent(), global_position + Vector2(0.0, -40.0), "Trunk's full!")
		return
	var scene := ResourceLoader.load(MATTRESS_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as GrandpaMattressCutscene
	if scene != null:
		scene.garage = self
		await Cutscenes.play(scene)
	if Inventory.give_item(NICKEL):
		Sfx.play(&"part_pickup", -6.0, 0.0)
	SaveSystem.save_game()
