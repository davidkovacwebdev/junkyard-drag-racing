class_name SmithConfrontCutscene
extends CoinsCutscene
## "Ask Around", after the beggar's tip about a man in a welding mask: the
## player goes back to Gus the smith and puts it to him. He just throws them
## out again. A dead end; the truth comes out in "Graveyard Shift". Played
## once, by ForgeSmith.
##
## The words live in res://cutscenes/smith_confront.tres.

const ID := &"smith_confront"

@export var again_line: String = "You again? What now?"
@export var accuse_line: String = "I think you have something to do with the new appearances of fake treasures."
@export var leave_line: String = "LEAVE!"

func _init() -> void:
	id = ID

func play() -> void:
	if not await stage():
		return
	await npc_says(again_line)
	await i_say(accuse_line)
	Cutscenes.sound(&"forge_hammer", -2.0)
	Cutscenes.shake(16.0, 0.45)
	Cutscenes.hop(npc, 34.0)
	await npc_says(leave_line)
	if player != null:
		var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
		if car != null:
			await Cutscenes.walk(player, car.global_position + Vector2(0.0, 14.0), 240.0)
			Cutscenes.sound(&"door_close", -6.0)
	unstage()
