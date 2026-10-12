@tool
class_name Hospital
extends ComposedBuilding
## The town hospital. Its doors stay shut ("visiting hours are over") except
## while "Bad News" is on: then E walks in to the morgue
## (scenes/hospital/hospital.tscn), where Grandpa lies under a sheet.
##
## Out front, a red-cross sign left of the door and a "no honking" sign right
## of it, and around them the quiet zone that calls the police on a player who
## leans on the horn (HospitalQuietZone). All added from here rather than
## placed in main.tscn, after the building has settled onto its ground line.
## The hospital y-sorts its children so each sign sorts at its own post base.

const QUEST_ID := &"hospital_visit"
const MORGUE_SCENE := "res://scenes/hospital/hospital.tscn"
const LOCKED_COLOR := Color(0.75, 0.75, 0.72)
const CROSS_SIGN := preload("res://scenes/world/hospital_sign.tscn")
const NO_HORN_SIGN := preload("res://scenes/world/no_horn_sign.tscn")
const CROSS_SIGN_SPOT := Vector2(-165.0, 47.0)
const NO_HORN_SIGN_SPOT := Vector2(165.0, 47.0)

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	y_sort_enabled = true
	_add_sign(CROSS_SIGN, "CrossSign", CROSS_SIGN_SPOT)
	_add_sign(NO_HORN_SIGN, "NoHornSign", NO_HORN_SIGN_SPOT)
	var zone := HospitalQuietZone.new()
	zone.name = "QuietZone"
	add_child(zone)

func _add_sign(scene: PackedScene, sign_name: String, spot: Vector2) -> void:
	var sign := scene.instantiate() as Node2D
	sign.name = sign_name
	sign.position = spot
	add_child(sign)

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
