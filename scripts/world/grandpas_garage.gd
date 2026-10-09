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

const QUEST_ID := &"grandpa_missing"
const SCENE_PATH := "res://cutscenes/grandpa_gone.tres"
const MATTRESS_QUEST := &"mattress_nickel"
const MATTRESS_SCENE_PATH := "res://cutscenes/grandpa_mattress.tres"
const NICKEL := preload("res://items/old_nickel.tres")

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
