class_name SmithyRaidCutscene
extends CoinsCutscene
## "Strike While It's Hot": the player pulls up at the Scrap Forge with Chad
## riding along. The two of them climb out and corner Gus at his forge, and it
## goes the way it does when his pickup is rammed to a stop at night: he owns
## up to planting the fakes and, when the player sets Chad and his baton on
## him (Chad winks at him), marks where he found the real coin
## (TreasureDigSpot). Played once by
## TreasureStory when the car gets close.
##
## The lines are NightDiggerCutscene's (res://cutscenes/night_digger.tres), so
## both ways of catching him say the same thing, except the baton threat:
## Chad's standing right there, so it's `baton_line` here.

const ID := &"smithy_raid"
const CHAD := preload("res://characters/chad.tres")
const NIGHT_LINES_PATH := "res://cutscenes/night_digger.tres"

## Said instead of the night scene's "I'll call my grandpa's gay brother".
@export var baton_line: String = "If you don't tell me, my gay police uncle will use his baton to make you say it."

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(npc_rig):
		return
	var lines := ResourceLoader.load(NIGHT_LINES_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as NightDiggerCutscene
	var at := npc_rig.global_position
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else at + Vector2(220.0, 20.0)
	var side := 1.0 if from.x > at.x else -1.0
	# Chad climbs out of the passenger side and follows the player in.
	var chad := Cutscenes.spawn_actor(CHAD, from + Vector2(30.0 * side, 24.0), side < 0.0)
	Cutscenes.sound(&"door_close", -8.0)
	var chad_spot := at + Vector2(210.0 * side, 14.0)
	Cutscenes.walk(chad, chad_spot, 150.0)
	if not await stage():
		return
	Cutscenes.face(chad, side < 0.0)

	await i_say(lines.caught_line)
	await npc_says(lines.so_what_line)
	await i_say(lines.keep_line)
	await npc_says(lines.bite_me_line)
	await i_say(lines.where_line)
	await npc_says(lines.not_saying_line)
	await i_say(baton_line)
	# The uncle in question gives Gus a wink.
	Cutscenes.face(chad, npc.global_position.x > chad.global_position.x)
	chad.wink(-6.0)
	await Cutscenes.wait(0.8)
	Cutscenes.hop(npc, 20.0)
	await npc_says(lines.alright_line)

	Cutscenes.sound(&"paper_unfold", -4.0)
	TreasureDigSpot.place(Cutscenes.get_tree().current_scene.get_node_or_null(^"Sortables"))
	await Cutscenes.title_card(lines.marked_card, 2.0)
	await npc_says(lines.nothing_line)
	await Cutscenes.wait(0.5)
	await Cutscenes.fade_out(0.6)
	unstage()
