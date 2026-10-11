@tool
class_name Hospital
extends ComposedBuilding
## The town hospital. Its doors stay shut ("visiting hours are over") except
## while "Bad News" is on: then E walks in to the morgue
## (scenes/hospital/hospital.tscn), where Grandpa lies under a sheet.
##
## Out front, right of the door, a "no honking" sign, and around it the quiet
## zone that calls the police on a player who leans on the horn
## (HospitalQuietZone). Both are added from here rather than placed in
## main.tscn.

const QUEST_ID := &"hospital_visit"
const MORGUE_SCENE := "res://scenes/hospital/hospital.tscn"
const LOCKED_COLOR := Color(0.75, 0.75, 0.72)
const NO_HORN_SIGN := preload("res://scenes/world/no_horn_sign.tscn")
## Mirrors the red-cross sign on the other side of the door.
const NO_HORN_SIGN_SPOT := Vector2(165.0, 110.0)

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	var sign := NO_HORN_SIGN.instantiate() as Node2D
	sign.name = "NoHornSign"
	sign.position = NO_HORN_SIGN_SPOT
	add_child(sign)
	var zone := HospitalQuietZone.new()
	zone.name = "QuietZone"
	add_child(zone)

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
