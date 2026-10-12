class_name FarmerCoinsCutscene
extends CoinsCutscene
## "Ask Around" at the farm: asked about the Junkyard Treasure, the horse
## farmer shows the player one of the coins he keeps finding. It's a fake
## ("tresure"), and they've only been turning up lately, so he agrees to keep
## an eye out for whoever's planting them. Played once, by HorseFarmer.
##
## The words live in res://cutscenes/farmer_coins.tres.

const ID := &"farmer_coins"

@export var coins_line: String = "Oh, now that you mention it, I do find these coins often."
@export var typo_line: String = "I think these are fake, look at the typo here. Were you always finding these?"
@export var recent_line: String = "Nope, it started relatively recently."
@export var watch_line: String = "Can you keep an eye out for me? See if anyone's planting these?"
@export var sure_line: String = "Sure, I guess."
@export var thanks_line: String = "Thanks."

func _init() -> void:
	id = ID

func play() -> void:
	if not await stage():
		return
	await npc_says(coins_line)
	var coin := await hold_out_coin()
	Cutscenes.sound(&"wink_ting", -10.0)
	var closeup := CoinCloseup.open([CoinCloseup.FAKE])
	await Cutscenes.wait(0.8)
	closeup.mark(0)
	await i_say(typo_line)
	closeup.close()
	await Cutscenes.camera_to(two_shot, zoom, 0.5)
	if is_instance_valid(coin):
		coin.queue_free()
	await npc_says(recent_line)
	await i_say(watch_line)
	await npc_says(sure_line)
	await i_say(thanks_line)
	await Cutscenes.wait(0.4)
	unstage()
