class_name MarkSpotCutscene
extends Cutscene
## "Beep Beep", over the treasure: the metal detector's going nuts, so the
## player climbs out to mark the spot. Nothing to mark it with but Grandpa's
## old prosthetic leg, so in it goes, upside down (TreasureMark). Played by
## TreasureStory when the player presses E right over it, which then
## finishes the quest.
##
## The words live in res://cutscenes/mark_spot.tres; edit them in the
## inspector.

const ID := &"mark_spot"

@export var leg_line: String = "Hmm, what can I use to mark the spot.. I'll just use Grandpa's fake leg lol"

@export_group("Staging")
@export var zoom: float = 1.7

## Set by TreasureStory before playing: the exact spot.
var spot: Vector2

func _init() -> void:
	id = ID

func play() -> void:
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else spot + Vector2(160.0, 20.0)
	var side := 1.0 if from.x > spot.x else -1.0
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, from + Vector2(-30.0 * side, 16.0), side < 0.0)
		Cutscenes.sound(&"door_close", -6.0)
	await Cutscenes.camera_to(spot + Vector2(50.0 * side, -100.0), zoom, 0.7)
	if player != null:
		await Cutscenes.walk(player, spot + Vector2(60.0 * side, 6.0), 140.0)
		Cutscenes.face(player, side < 0.0)
	await Cutscenes.subtitle(my_name, me, leg_line, player)
	# In it goes.
	if player != null:
		await Cutscenes.hop(player, 14.0)
	Cutscenes.sound(&"wood_clonk", -4.0)
	TreasureMark.place(Cutscenes.get_tree().current_scene.get_node_or_null(^"Sortables"), spot)
	Cutscenes.shake(4.0, 0.2)
	await Cutscenes.wait(0.8)
	await Cutscenes.fade_out(0.5)
