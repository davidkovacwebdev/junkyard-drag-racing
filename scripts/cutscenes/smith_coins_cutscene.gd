class_name SmithCoinsCutscene
extends CoinsCutscene
## "Ask Around" at the scrap forge: Gus the smith can't stop talking about the
## Junkyard Treasure and shows off the "treasure parts" he's found. Checked
## one by one they're fakes ("tresure"), all but one: that one reads
## "treasure". Asked where he found it, he flies off the handle (he thinks the
## player wants it for themselves) and throws them out. Played once, by
## ForgeSmith.
##
## The words live in res://cutscenes/smith_coins.tres.

const ID := &"smith_coins"

@export var heard_line: String = "Oh, have I heard? It's all I talk about recently. I even found some treasure parts. Look at this."
@export var real_line: String = "This one seems real. Where did you find it?"
@export var rage_line: String = "AS IF I'LL TELL YOU! YOU WANT IT FOR YOURSELF!"
@export var protest_line: String = "No, I'm..."
@export var leave_line: String = "Leave my store."
## Which of the coins he shows is the real one.
@export var coins: Array[String] = ["TRESURE", "TRESURE", "TREASURE", "TRESURE"]

func _init() -> void:
	id = ID

func play() -> void:
	if not await stage():
		return
	await npc_says(heard_line)
	var coin := await hold_out_coin()
	var closeup := CoinCloseup.open(coins)
	await Cutscenes.wait(0.9)
	for i in coins.size():
		closeup.mark(i)
		await Cutscenes.wait(0.75)
	await i_say(real_line)
	closeup.close()
	if is_instance_valid(coin):
		coin.queue_free()
	await Cutscenes.camera_to(two_shot, zoom, 0.3)
	# He slams his hammer down.
	Cutscenes.sound(&"forge_hammer", -2.0)
	Cutscenes.shake(14.0, 0.4)
	Cutscenes.hop(npc, 30.0)
	await npc_says(rage_line)
	await i_say(protest_line)
	await npc_says(leave_line)
	# Shown the door: back to the car.
	if player != null:
		var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
		if car != null:
			await Cutscenes.walk(player, car.global_position + Vector2(0.0, 14.0), 220.0)
			Cutscenes.sound(&"door_close", -6.0)
	unstage()
