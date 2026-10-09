@tool
class_name Hospital
extends ComposedBuilding
## The town hospital. Its doors stay shut ("visiting hours are over") except
## while "Bad News" is on: then E walks in to the morgue
## (scenes/hospital/hospital.tscn), where Grandpa lies under a sheet.

const QUEST_ID := &"hospital_visit"
const MORGUE_SCENE := "res://scenes/hospital/hospital.tscn"
const LOCKED_COLOR := Color(0.75, 0.75, 0.72)

func is_open() -> bool:
	return Quests.has_quest(QUEST_ID)

func get_interact_prompt() -> String:
	if is_open():
		return "%s: Press E to go in" % display_name
	return "%s: Visiting hours are over" % display_name

func get_interact_prompt_color() -> Color:
	return Color(1, 1, 1, 1) if is_open() else LOCKED_COLOR

## Called by PlayerCar on E or a click.
func interact(_actor: Node = null) -> void:
	if not is_open():
		Sfx.play(&"denied", -6.0, 0.0)
		return
	Sfx.play(&"door_close", -4.0)
	SaveSystem.save_game()
	SceneLoader.change_scene(MORGUE_SCENE)
